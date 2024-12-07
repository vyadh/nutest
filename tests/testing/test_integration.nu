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

#[test]
def with-default-options [] {
    let temp = $in.temp

    let results = test-run $"run-tests --no-color --path '($temp)'"

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

    let results = test-run $"run-tests --no-color --path ($path)"

    assert equal $results [
        { suite: test_2, test: test_baz, result: "PASS", output: "zab" }
        { suite: test_2, test: test_qux, result: "SKIP", output: "" }
    ]
}

#[test]
def with-specific-test [] {
    let temp = $in.temp

    let results = test-run $"run-tests --no-color --path ($temp) --match-tests test_foo"

    assert equal $results [
        { suite: test_1, test: test_foo, result: "PASS", output: "oof" }
    ]
}

#[test]
def with-test-pattern [] {
    let temp = $in.temp

    let results = test-run $"run-tests --no-color --path ($temp) --match-tests 'test_ba[rz]'"

    assert equal $results [
        { suite: test_1, test: test_bar, result: "PASS", output: "rab" }
        { suite: test_2, test: test_baz, result: "PASS", output: "zab" }
    ]
}

#[test]
def with-specific-suite [] {
    let temp = $in.temp

    let results = test-run $"run-tests --no-color --path ($temp) --match-suites test_1"

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
                run-tests --no-color --path ($temp) --fail
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
                run-tests --no-color --path ($temp) --fail
            "
    ) | complete

    assert equal $result.exit_code 1
    assert ($result.stdout =~ "test_3[ │]+test_quux[ │]+FAIL[ │]+Ouch") "Tests are output"
}
