use std/assert
use harness.nu
use ../nutest/formatter.nu
use ../nutest/theme.nu
use ../nutest/reporter_table.nu

#[before-all]
def setup-tests []: record -> record {
    let formatter = formatter pretty (theme none) "compact" # Unless overridden
    $in | harness setup-tests $formatter
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
def "assertion compact" [] {
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

#[test]
def "basic compact" [] {
    let code = {
        error make { msg: 'some error' }
    }

    let output = $in | run $code

    assert equal $output "some error"
}

#[test]
def "full preserved" [] {
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

    # Formatter that preserves all type information (pass-through)
    let formatter = formatter preserved
    let reporter = reporter_table create (theme none) $formatter
    let context = $in | merge { reporter: $reporter }
    let output = $context | run $code

    assert equal ($output.stream) ["error"]
    let details = $output.items | first | get json.0 | from json
    assert equal ($details.msg) "a decorated error"
    assert equal ($details.labels.0.text) "happened here"
    assert equal ($details.help) "some help"
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

    # Use 'unformatted' formatter
    let formatter = formatter unformatted
    let reporter = reporter_table create (theme none) $formatter
    let context = $in | merge { reporter: $reporter }
    let output = $context | run $code

    let details = $output.0.json | from json
    assert equal ($details.msg) "a decorated error"
    assert equal ($details.labels.0.text) "happened here"
    assert equal ($details.help) "some help"
}

#[test]
def "full rendered" [] {
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

    # Use a pretty-printing formatter
    let formatter = formatter pretty (theme none) "rendered"
    let reporter = reporter_table create (theme none) $formatter
    let context = $in | merge { reporter: $reporter }
    let output = $context | run $code

    assert str contains $output "a decorated error"
    assert str contains $output "happened here"
    assert str contains $output "some help"
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

    # Use a compact-printing formatter
    let formatter = formatter pretty (theme none) "compact"
    let reporter = reporter_table create (theme none) $formatter
    let context = $in | merge { reporter: $reporter }
    let output = $context | run $code

    assert equal $output "a decorated error\nsome help"
}

def run [code: closure]: record -> string {
    let result = $in | harness run $code
    assert equal $result.result "FAIL"
    $result.output
}

def trim-all []: string -> string {
    $in | str trim | str replace --all --regex '[\n\t ]+' ' '
}
