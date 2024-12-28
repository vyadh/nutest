use std/assert

# To avoid collisions with the database, we run each test  in a subshell.

#[before-each]
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
    #[test]
    def test_foo [] { print oof }
    #[test]
    def test_bar [] { print -e rab }
    " | save $test_file_1

    "
    #[test]
    def test_baz [] { print zab }
    #[ignore]
    def test_qux [] { print xuq }
    def test_quux [] { print xuuq }
    " | save $test_file_2
}

#[after-each]
def cleanup [] {
    let context = $in
    rm --recursive $context.temp
}

#[test]
def with-default-table-options [] {
    let temp = $in.temp

    let results = test-run $"run-tests --path '($temp)' --reporter table"

    assert equal $results [
        { suite: test_1, test: test_bar, result: "PASS", output: ["rab"] }
        { suite: test_1, test: test_foo, result: "PASS", output: ["oof"] }
        { suite: test_2, test: test_baz, result: "PASS", output: ["zab"] }
        { suite: test_2, test: test_qux, result: "SKIP", output: [] }
    ]
}

#[test]
def with-different-formatter [] {
    let temp = $in.temp

    let results = test-run $"run-tests --path '($temp)' --reporter table --formatter preserve"

    assert equal $results [
        { suite: test_1, test: test_bar, result: "PASS", output: [{stream: "error", items: "rab"}] }
        { suite: test_1, test: test_foo, result: "PASS", output: [{stream: "output", items: "oof"}] }
        { suite: test_2, test: test_baz, result: "PASS", output: [{stream: "output", items: "zab"}] }
        { suite: test_2, test: test_qux, result: "SKIP", output: [] }
    ]
}

#[test]
def with-specific-file [] {
    let temp = $in.temp
    let path = $temp | path join "test_2.nu"

    let results = test-run $"run-tests --path '($path)' --reporter table"

    assert equal $results [
        { suite: test_2, test: test_baz, result: "PASS", output: ["zab"] }
        { suite: test_2, test: test_qux, result: "SKIP", output: [] }
    ]
}

#[test]
def with-specific-test [] {
    let temp = $in.temp

    let results = test-run $"run-tests --path '($temp)' --reporter table --match-tests test_foo"

    assert equal $results [
        { suite: test_1, test: test_foo, result: "PASS", output: ["oof"] }
    ]
}

#[test]
def with-test-pattern [] {
    let temp = $in.temp

    let results = test-run $"run-tests --path '($temp)' --reporter table --match-tests 'test_ba[rz]'"

    assert equal $results [
        { suite: test_1, test: test_bar, result: "PASS", output: ["rab"] }
        { suite: test_2, test: test_baz, result: "PASS", output: ["zab"] }
    ]
}

#[test]
def with-specific-suite [] {
    let temp = $in.temp

    let results = test-run $"run-tests --path '($temp)' --reporter table --match-suites test_1"

    assert equal $results [
        { suite: test_1, test: test_bar, result: "PASS", output: ["rab"] }
        { suite: test_1, test: test_foo, result: "PASS", output: ["oof"] }
    ]
}

#[test]
def exit-on-fail-with-passing-tests [] {
    let temp = $in.temp

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use std/testing *
                run-tests --path ($temp) --reporter table --formatter pretty --fail
            "
    ) | complete

    let output = $result.stdout
    assert equal $result.exit_code 0 "Exit code is 0"
    assert ($output =~ "test_1[ │]+test_foo[ │]+PASS[ │]+oof") "Tests    are output"
}

# todo We should decide how to format errors in tables
#[ignore]
def exit-on-fail-with-failing-tests [] {
    let temp = $in.temp
    let test_file_3 = $temp | path join "test_3.nu"
    "
    #[test]
    def test_quux [] { error make { msg: 'Ouch' } }
    " | save $test_file_3

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use std/testing *
                run-tests --path ($temp) --reporter table --formatter pretty --fail
            "
    ) | complete

    assert equal $result.exit_code 1
    assert ($result.stdout =~ "test_3[ │]+test_quux[ │]+FAIL[ │]+Ouch") "Tests are output"
}

#[test]
def useful-error-on-non-existent-path [] {
    let missing_path = [(pwd), "non", "existant", "path"] | path join
    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use std/testing *
                run-tests --path ($missing_path)
            "
    ) | complete

    assert str contains $result.stderr $"Path doesn't exist: ($missing_path)"
    assert equal $result.exit_code 1
}

#[test]
def with-summary-reporter [] {
    let temp = $in.temp
    let test_file_3 = $temp | path join "test_3.nu"
    "
    #[test]
    def test_quux [] { error make { msg: 'Ouch' } }
    #[ignore]
    def test_oof [] { }
    " | save $test_file_3

    let results = test-run $"run-tests --path '($temp)' --reporter summary"

    assert equal $results {
        total: 6
        passed: 3
        failed: 1
        skipped: 2
    }
}

#[test]
def list-tests-as-table [] {
    let temp = $in.temp

    "
    #[test]
    def test_zat [] { print oof }
    #[before-each]
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

#[test]
def with-terminal-reporter [] {
    let temp = $in.temp
    let test_file_3 = $temp | path join "test_3.nu"
    "
    #[test]
    def test_quux [] { error make { msg: 'Ouch' } }
    #[ignore]
    def test_oof [] { }
    " | save $test_file_3

    let results = test-run-raw $"run-tests --path '($temp)' --reporter terminal --strategy { threads: 1 }"
        | ansi strip

    # The ordering of the suites is currently indeterminate so we need to match tests specifically
    assert ($results | str starts-with "Running tests...")
    assert ($results =~ $"✅ PASS test_1 test_foo\n  oof")
    assert ($results =~ $"✅ PASS test_1 test_bar\n  rab")
    assert ($results =~ $"✅ PASS test_2 test_baz\n  zab")
    assert ($results =~ $"🚧 SKIP test_2 test_qux")
    assert ($results =~ $"❌ FAIL test_3 test_quux\n  Error:[\n ]+× Ouch")
    assert ($results =~ $"🚧 SKIP test_3 test_oof")
    assert ($results | str ends-with "Test run completed: 6 total, 3 passed, 1 failed, 2 skipped\n")
}

def sort-lines []: string -> list<string> {
    $in | str trim | split row "\n" | sort
}

def test-run [command: string] {
    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use std/testing *
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
                use std/testing *
                ($command)
            "
    ) | complete

    if $result.exit_code != 0 {
        $"[sub-process failed: ($result.stderr)]"
    } else {
        $result.stdout
    }
}
