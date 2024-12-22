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
def with-default-options [] {
    let temp = $in.temp

    let results = test-run $"run-tests --reporter table --path '($temp)'"

    assert equal $results [
        { suite: test_1, test: test_bar, result: "PASS", output: "rab" }
        { suite: test_1, test: test_foo, result: "PASS", output: "oof" }
        { suite: test_2, test: test_baz, result: "PASS", output: "zab" }
        { suite: test_2, test: test_qux, result: "SKIP", output: "" }
    ]
}

#[test]
def with-specific-file [] {
    let temp = $in.temp
    let path = $temp | path join "test_2.nu"

    let results = test-run $"run-tests --reporter table --path ($path)"

    assert equal $results [
        { suite: test_2, test: test_baz, result: "PASS", output: "zab" }
        { suite: test_2, test: test_qux, result: "SKIP", output: "" }
    ]
}

#[test]
def with-specific-test [] {
    let temp = $in.temp

    let results = test-run $"run-tests --reporter table --path ($temp) --match-tests test_foo"

    assert equal $results [
        { suite: test_1, test: test_foo, result: "PASS", output: "oof" }
    ]
}

#[test]
def with-test-pattern [] {
    let temp = $in.temp

    let results = test-run $"run-tests --reporter table --path ($temp) --match-tests 'test_ba[rz]'"

    assert equal $results [
        { suite: test_1, test: test_bar, result: "PASS", output: "rab" }
        { suite: test_2, test: test_baz, result: "PASS", output: "zab" }
    ]
}

#[test]
def with-specific-suite [] {
    let temp = $in.temp

    let results = test-run $"run-tests --reporter table --path ($temp) --match-suites test_1"

    assert equal $results [
        { suite: test_1, test: test_bar, result: "PASS", output: "rab" }
        { suite: test_1, test: test_foo, result: "PASS", output: "oof" }
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
                run-tests --reporter table --path ($temp) --fail
            "
    ) | complete

    assert equal $result.exit_code 0 "Exit code is 0"
    assert ($result.stdout =~ "test_1[ │]+test_foo[ │]+PASS[ │]+oof") "Tests are output"
}

#[test]
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
                run-tests --reporter table --path ($temp) --fail --strategy { error_format: compact }
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

    let results = test-run $"run-tests --reporter summary --path ($temp)"

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

#[ignore]
# TODO Fix error colouring
def with-terminal-reporter [] {
    let temp = $in.temp
    let test_file_3 = $temp | path join "test_3.nu"
    "
    #[test]
    def test_quux [] { error make { msg: 'Ouch' } }
    #[ignore]
    def test_oof [] { }
    " | save $test_file_3

    let results = test-run-raw $"run-tests --reporter terminal --path ($temp) --strategy { threads: 1, error_format: compact }"

    # The ordering of the suites is currently indeterminate so we need to sort lines
    assert equal ($results | sort-lines) ($"Running tests...
✅ (ansi green)PASS(ansi reset) (ansi light_blue)test_1(ansi reset) test_foo
  oof
✅ (ansi green)PASS(ansi reset) (ansi light_blue)test_1(ansi reset) test_bar
  (ansi yellow)rab(ansi reset)
✅ (ansi green)PASS(ansi reset) (ansi light_blue)test_2(ansi reset) test_baz
  zab
🚧 (ansi yellow)SKIP(ansi reset) (ansi light_blue)test_2(ansi reset) test_qux
❌ (ansi red)FAIL(ansi reset) (ansi light_blue)test_3(ansi reset) test_quux
  (ansi yellow)Ouch(ansi reset)
🚧 (ansi yellow)SKIP(ansi reset) (ansi light_blue)test_3(ansi reset) test_oof
Test run completed: 6 total, 3 passed, 1 failed, 2 skipped" | sort-lines)

    # Ensure error is associated with the right test
    assert str contains $results ($"
❌ (ansi red)FAIL(ansi reset) (ansi light_blue)test_3(ansi reset) test_quux
  (ansi yellow)Ouch(ansi reset)" | str trim)
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

def test-run-raw [command: string] {
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
