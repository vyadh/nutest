use std/assert
use std/testing *

# To avoid collisions with the database, we run each test  in a subshell.

@before-each
def setup []: nothing -> record {
    let temp = mktemp --tmpdir --directory
    setup-tests $temp

    {
        temp: $temp
    }
}

def setup-tests [temp: string] {
    let test_file_1 = $temp | path join "test_1.nu"
    let test_file_2 = $temp | path join "test_2.nu"

    "
    use std/testing *

    @test
    def test_foo [] { print oof }
    @test
    def test_bar [] { print -e rab }
    " | save $test_file_1

    "
    use std/testing *

    @test
    def test_baz [] { print zab }
    @ignore
    def test_qux [] { print xuq }
    def test_quux [] { print xuuq }
    " | save $test_file_2
}

@after-each
def cleanup [] {
    let context = $in
    rm --recursive $context.temp
}

@test
def with-default-table-options [] {
    let temp = $in.temp

    let results = test-run $"run-tests --path '($temp)' --returns table"

    assert equal $results [
        { suite: test_1, test: test_bar, result: "PASS", output: ["rab"] }
        { suite: test_1, test: test_foo, result: "PASS", output: ["oof"] }
        { suite: test_2, test: test_baz, result: "PASS", output: ["zab"] }
        { suite: test_2, test: test_qux, result: "SKIP", output: [] }
    ]
}

@test
def with-different-returns [] {
    let temp = $in.temp

    let results = test-run $"run-tests --path '($temp)' --returns summary"

    assert equal $results {
        total: 4
        passed: 3
        failed: 0
        skipped: 1
    }
}

@test
def with-specific-file [] {
    let temp = $in.temp
    let path = $temp | path join "test_2.nu"

    let results = test-run $"run-tests --path '($path)' --returns table"

    assert equal $results [
        { suite: test_2, test: test_baz, result: "PASS", output: ["zab"] }
        { suite: test_2, test: test_qux, result: "SKIP", output: [] }
    ]
}

@test
def with-matching-suite-and-test [] {
    let temp = $in.temp

    let results = test-run $"run-tests --path '($temp)' --returns table --match-suites _1 --match-tests test_ba[rz]"

    assert equal $results [
        { suite: test_1, test: test_bar, result: "PASS", output: ["rab"] }
    ]
}

@test
def "fail option still returns result on passing tests" [] {
    let temp = $in.temp

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands ($"
                use nutest *
                run-tests --path ($temp) --fail --display table --returns summary
                    | get total" + ' | $"Total: ($in)"'
            )
    ) | complete

    let output = $result.stdout | ansi strip
    assert ($output =~ "test_1[ │]+test_foo[ │]+✅ PASS[ │]+") "Table is output"
    assert ($output =~ "Total: 4") "Result is available to query"
    assert equal $result.exit_code 0 "Exit code is 0"
}

@test
def "fail option exit code on failing tests" [] {
    let temp = $in.temp
    let test_file_3 = $temp | path join "test_3.nu"
    "
    use std/testing *

    @test
    def test_quux [] { error make { msg: 'Ouch' } }
    " | save $test_file_3

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use nutest *
                run-tests --path ($temp) --returns table --fail
            "
    ) | complete

    let output = $result.stdout | ansi strip
    assert ($output =~ "test_3[ │]+test_quux[ │]+FAIL[ │]+") "Tests are output"
    assert equal $result.exit_code 1
}

@test
def useful-error-on-non-existent-path [] {
    let missing_path = ["non", "existant", "path"] | path join
    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use nutest *
                run-tests --path ($missing_path)
            "
    ) | complete

    assert str contains $result.stderr $"Path doesn't exist: "
    assert str contains $result.stderr $missing_path
    assert equal $result.exit_code 1
}

@test
def with-summary-returns [] {
    let temp = $in.temp
    let test_file_3 = $temp | path join "test_3.nu"
    "
    use std/testing *

    @test
    def test_quux [] { error make { msg: 'Ouch' } }
    @ignore
    def test_oof [] { }
    " | save $test_file_3

    let results = test-run $"run-tests --path '($temp)' --returns summary"

    assert equal $results {
        total: 6
        passed: 3
        failed: 1
        skipped: 2
    }
}

@test
def list-tests-as-table [] {
    let temp = $in.temp

    "
    use std/testing *

    @test
    def test_zat [] { print oof }
    @before-each
    def setup [] { print -e rab }
    " | save ($temp | path join "test_3.nu")

    let results = test-run $"list-tests --path ($temp)"

    assert equal $results [
        { suite: test_1, test: test_bar }
        { suite: test_1, test: test_foo }
        { suite: test_2, test: test_baz }
        { suite: test_2, test: test_qux }
        { suite: test_3, test: test_zat }
    ]
}

@ignore
@test
def "terminal display" [] {
    let temp = $in.temp
    let test_file_3 = $temp | path join "test_3.nu"
    "
    use std/testing *

    @test
    def test_quux [] { error make { msg: 'Ouch' } }
    @ignore
    def test_oof [] { }
    " | save $test_file_3

    let results = test-run-raw $"run-tests --path '($temp)' --display terminal --strategy { threads: 1 }"
        | ansi strip

    # The ordering of the suites is currently indeterminate so we need to match tests specifically
    assert ($results | str starts-with "Running tests...")
    assert ($results =~ "✅ PASS test_1 test_foo\n  oof")
    assert ($results =~ "✅ PASS test_1 test_bar\n  rab")
    assert ($results =~ "✅ PASS test_2 test_baz\n  zab")
    assert ($results =~ "🚧 SKIP test_2 test_qux")
    # We use '.' as version 0.101.0 used '×', newer versions use 'x'
    # We need to account for chained errors introduced in 0.103.0 here
    assert ($results =~ "❌ FAIL test_3 test_quux(?:.|\n)*?Error:[\n ]+[×x] Ouch")
    assert ($results =~ "🚧 SKIP test_3 test_oof")
    assert ($results | str ends-with "Test run completed: 6 total, 3 passed, 1 failed, 2 skipped\n")
}

@test
def "terminal display with rendered error" [] {
    let temp = $in.temp
    let test_file_3 = $temp | path join "test_3.nu"
    "
    use std/testing *

    @test
    def test_quux [] {
        let variable = 'span source'

        error make {
            msg: 'a decorated error'
            label: {
                text: 'happened here'
                span: (metadata $variable).span
            }
            help: 'some help'
        }
    }
    " | save $test_file_3

    let results = test-run-raw $"run-tests --path '($test_file_3)' --display terminal --strategy { threads: 1 }"
        | ansi strip

    assert str contains $results "a decorated error"
    assert str contains $results "happened here"
    assert str contains $results "some help"
}

@test
def with-junit-report [] {
    let temp = $in.temp
    let test_file_3 = $temp | path join "test_3.nu"
    "
    use std/testing *

    @test
    def test_quux [] { error make { msg: 'Ouch' } }
    @ignore
    def test_oof [] { }
    " | save $test_file_3
    let report_path = $temp | path join "report.xml"

    test-run-raw $"run-tests --path '($temp)' --report { type: junit, path: '($report_path)' }"

    assert equal ($report_path | open --raw | strip-xml-whitespace) ('<testsuites name="nutest" tests="6" disabled="2" failures="1">
  <testsuite name="test_1" tests="2" disabled="0" failures="0">
    <testcase name="test_bar" classname="test_1"/>
    <testcase name="test_foo" classname="test_1"/>
  </testsuite>
  <testsuite name="test_2" tests="2" disabled="1" failures="0">
    <testcase name="test_baz" classname="test_2"/>
    <testcase name="test_qux" classname="test_2">
      <skipped/>
    </testcase>
  </testsuite>
  <testsuite name="test_3" tests="2" disabled="1" failures="1">
    <testcase name="test_oof" classname="test_3">
      <skipped/>
    </testcase>
    <testcase name="test_quux" classname="test_3">
      <failure type="Error" message=""></failure>
    </testcase>
  </testsuite>
</testsuites>
' | strip-xml-whitespace)
}

def test-run [command: string] {
    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use nutest *
                ($command) | to nuon
            "
    ) | complete

    if $result.exit_code != 0 {
        $"[sub-process failed: ($result.stderr)]"
    } else {
        $result.stdout | from nuon
    }
}

def test-run-raw [command: string]: nothing -> string {
    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use nutest *
                ($command)
            "
    ) | complete

    if $result.exit_code != 0 {
        $"[sub-process failed: ($result.stderr)]"
    } else {
        $result.stdout
    }
}

def strip-xml-whitespace []: string -> string {
    $in | str trim | str replace --all --regex '>[\n\r ]+<' '><'
}
