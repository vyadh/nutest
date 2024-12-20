use std/assert
use harness.nu

# [before-all]
def setup-tests []: record -> record {
    $in | harness setup-tests
}

# [after-all]
def cleanup-tests []: record -> nothing {
    $in | harness cleanup-tests
}

# [before-each]
def setup-test []: record -> record {
    $in | harness setup-test
}

# [after-each]
def cleanup-test []: record -> nothing {
    $in | harness cleanup-test
}

# [test]
def assertion-failure [] {
    let test = {
        assert equal 1 2
    }

    let output = $in | run $test

    assert equal ($output | trim-all) ("
        Assertion failed.
        These are not equal.
        |>Left  : '1'
        |>Right : '2'
    " | trim-all)
}

# [test]
def basic-error [] {
    let code = {
        error make { msg: 'some error' }
    }

    let output = $in | run $code

    assert str contains $output "some error"
}

# [test]
def full-rendered-error [] {
    let code = {
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

    let strategy = { error_format: "rendered" }
    let output = $in | run $code $strategy

    assert str contains $output "a decorated error"
    assert str contains $output "happened here"
    assert str contains $output "some help"
}

# [test]
def full-compact-error [] {
    let code = {
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

    let strategy = { error_format: "compact" }
    let output = $in | run $code $strategy

    assert equal $output "a decorated error\nsome help"
}

def run [code: closure, strategy: record = { }]: record -> string {
    let result = $in | harness run $code $strategy
    assert equal $result.result "FAIL"
    $result.output
}

def trim-all []: string -> string {
    $in | str trim | str replace --all --regex '[\n\t ]+' ' '
}
