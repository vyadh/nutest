use std/assert
use ../../std/testing

#[before-each]
def setup [] -> record {
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
