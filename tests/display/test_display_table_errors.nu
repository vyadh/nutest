use std/assert
use ../harness.nu
use ../../nutest/formatter.nu
use ../../nutest/theme.nu
use ../../nutest/display/display_table.nu
use ../../nutest/errors.nu


#[before-all]
def setup-tests []: record -> record {
    $in | harness setup-tests
}

#[after-all]
def cleanup-tests []: record -> nothing {
    $in | harness cleanup-tests
}

#[before-each]
def setup-test []: record -> record {
    $in | harness setup-test
}

#[after-each]
def cleanup-test []: record -> nothing {
    $in | harness cleanup-test
}

#[test]
def "assertion is compact" [] {
    let test = {
        assert equal 1 2
    }

    let result = $in | run $test

    assert equal ($result.output | trim-all) ("
        Assertion failed.
        These are not equal.
        |>Left  : '1'
        |>Right : '2'
    " | trim-all)
}

#[test]
def "basic compact" [] {
    let code = {
        error make { msg: 'some error' }
    }

    let result = $in | run $code

    assert equal $result.output "some error"
}

#[test]
def "full unformatted" [] {
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

    # Use default 'unformatted' formatter
    let result = $in | run $code

    let error = $result.data.output.0 | errors unwrap-error
    let details = $error.json | from json
    assert equal ($details.msg) "a decorated error"
    assert equal ($details.labels.0.text) "happened here"
    assert equal ($details.help) "some help"
}

#[test]
def "full compact" [] {
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

    let result = $in | run $code

    assert equal $result.output "a decorated error\nsome help"
}

# See test_integration.nu / "terminal display with rendered error" for rendered test

def run [code: closure]: record -> record<data: record, output: string> {
    let result = $in | harness run $code
    assert equal $result.result "FAIL"

    let output = do (display_table create).results
        | where test == $result.test
        | first
        | get output
        | ansi strip

    {
        data: $result
        output: $output
    }
}

def trim-all []: string -> string {
    $in | str trim | str replace --all --regex '[\n\r\t ]+' ' '
}
