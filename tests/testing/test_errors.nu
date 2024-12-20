use std/assert
use harness.nu

# [before-all]
def reporter-setup []: record -> record {
    $in | harness start-tests
}

# [after-all]
def reporter-complete []: record -> nothing {
    $in | harness tests-complete
}

# [before-each]
def setup-temp-dir []: record -> record {
    $in | harness with-temp-dir
}

# [after-each]
def cleanup-temp-dir []: record -> nothing {
    $in | harness cleanup-test
}

# [test]
def assertion-failure [] {
    let test = "assert equal 1 2"

    let output = $in | test-run $test

    assert equal ($output | trim-all) ("
        Assertion failed.
        These are not equal.
        |>Left  : '1'
        |>Right : '2'
    " | trim-all)
}

# [test]
def basic-error [] {
    let test = "error make { msg: 'some error' }"

    let output = $in | test-run $test

    assert str contains $output "some error"
}

# [test]
def rendered-error [] {
    let test = "
        let variable = 'span source'

        error make {
            msg: 'a decorated error'
            label: {
                text: 'happened here'
                span: (metadata $variable).span
            }
            help: 'some help'
        }"

    let output = $in | test-run $test { error_format: "rendered" }

    assert str contains $output "a decorated error"
    assert str contains $output "happened here"
    assert str contains $output "some help"
}

def test-run [code: string, strategy: record = { }]: record -> string {
    let result = $in | harness run-code $code $strategy
    assert equal $result.result "FAIL"
    $result.output
}
