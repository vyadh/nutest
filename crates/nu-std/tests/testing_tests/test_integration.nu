use std/assert
use ../../std/testing

#[before-each]
def setup []: nothing -> record {
    let temp = mktemp --tmpdir --directory

    setup-tests $temp

    {
        temp: $temp
    }
}

#[after-each]
def cleanup [] {
    let context = $in
    rm --recursive $context.temp
}

def setup-tests [temp: string] {
    let test_file_1 = $temp | path join "test_1.nu"
    let test_file_2 = $temp | path join "test_2.nu"

    "
    #[test]
    def test_foo [] { print oof }
    #[test]
    def test_bar [] { print -e rab}
    " | save $test_file_1

    "
    #[test]
    def test_baz [] { print zab }
    def test_qux [] { print xuq }
    " | save $test_file_2
}

#[test]
def test-with-default-options [] {
    let temp = $in.temp

    let results = testing --path $temp

    assert equal $results [
        { suite: test_1, test: test_bar, success: true, output: "", error: "rab" }
        { suite: test_1, test: test_foo, success: true, output: "oof", error: "" }
        { suite: test_2, test: test_baz, success: true, output: "zab", error: "" }
    ]
}

#[test]
def test-with-specific-file [] {
    let temp = $in.temp

    let results = testing --path ($temp | path join "test_2.nu")

    assert equal $results [
        { suite: test_2, test: test_baz, success: true, output: "zab", error: "" }
    ]
}

#[test]
def test-with-specific-test [] {
    let temp = $in.temp

    let results = testing --path $temp --test test_foo

    assert equal $results [
        { suite: test_1, test: test_foo, success: true, output: "oof", error: "" }
    ]
}

#[test]
def test-with-test-pattern [] {
    let temp = $in.temp

    let results = testing --path $temp --test 'test_ba[rz]'

    assert equal $results [
        { suite: test_1, test: test_bar, success: true, output: "", error: "rab" }
        { suite: test_2, test: test_baz, success: true, output: "zab", error: "" }
    ]
}

#[test]
def test-with-specific-suite [] {
    let temp = $in.temp

    let results = testing --path $temp --suite test_1

    assert equal $results [
        { suite: test_1, test: test_bar, success: true, output: "", error: "rab" }
        { suite: test_1, test: test_foo, success: true, output: "oof", error: "" }
    ]
}

#[ignore] not sure how to best accomplish this yet
#[test]
def tests-should-have-appropriate-exit-code [] {
    let temp = $in.temp
    let test_file_3 = $temp | path join "test_3.nu"
    "
    #[test]
    def test_quux [] { error make { msg: 'Ouch' } }
    " | save $test_file_3

    let results = testing --path $temp --suite test_1
    assert equal $env.LAST_EXIT_CODE "0"

    let results = testing --path $temp
    assert equal $env.LAST_EXIT_CODE "1"
    assert equal $results [
        { suite: test_1, test: test_bar, success: true, output: "", error: "rab" }
        { suite: test_1, test: test_foo, success: true, output: "oof", error: "" }
        { suite: test_2, test: test_baz, success: true, output: "zab", error: "" }
        { suite: test_3, test: test_quux, success: false, output: "", error: "Ouch" }
    ]
}
