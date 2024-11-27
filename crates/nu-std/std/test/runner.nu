#
# This script is used by the runner to directly invoke tests from the plan data.
#
#
# INPUT DATA STRUCTURES
#
# suite_data:
# [
#     {
#         name: string
#         type: string
#         execute: closure
#     }
# ]
#
# Where:
#   `type` can be "test", "before-all", etc.
#   `execute` is the closure function of `type`
#

# TODO prefix commands with something unusual to avoid conflicts

export def plan-execute-suite-emit [$suite: string, threads: int, suite_data: list] {
    with-env { NU_TEST_SUITE_NAME: $suite } {
        plan-execute-suite $threads $suite_data
    }

    # Don't output any result
    null
}

def plan-execute-suite [threads: int, suite_data: list] {
    let plan = $suite_data | group-by type

    let before_all = $plan | get-or-empty "before-all"
    let before_each = $plan | get-or-empty "before-each"
    let after_each = $plan | get-or-empty "after-each"
    let after_all = $plan | get-or-empty "after-all"
    let tests = $plan | get-or-empty "test"
    let ignored = $plan | get-or-empty "ignore"

    # TODO test exception handling
    let context_all = { } | execute-before $before_all

    $tests | par-each --threads $threads { |test|
        # Allow print output to be associated with specific tests by adding name to the environment
        with-env { NU_TEST_NAME: $test.name } {
            emit "start" { }

            # TODO clean this up a bit
            try {
                let context = $context_all | execute-before $before_each

                try {
                    $context | do $test.execute
                    $context | execute-after $after_each # TODO if throws, will exec again
                    emit "result" { status: "PASS" }
                } catch { |error|
                    emit "result" { status: "FAIL" }
                    print -e ...(format_error $error)
                    # TODO test exception handling, since this should still run
                    $context | execute-after $after_each
                }

            } catch { |error|
                emit "result" { status: "FAIL" }
                print -e ...(format_error $error)
                # TODO test exception handling, since this should still run
                $context_all | execute-after $after_each
            }

            emit "finish" { }
        }
    }

    for test in $ignored {
        with-env { NU_TEST_NAME: $test.name } {
            emit "start" { }
            emit "result" { status: "SKIP" }
            emit "finish" { }
        }
    }

    # TODO test exception handling
    $context_all | execute-after $after_all
}

def get-or-empty [key: string]: list -> list {
    $in | get --ignore-errors $key | default []
}

# TODO better message on incompatible signature where we don't supply the context
#   not: expected: input, and argument, to be both record or both
def execute-before [items: list]: record -> record {
    let initial_context = $in
    $items | reduce --fold $initial_context { |it, acc|
        let next = (do $it.execute)
        $acc | merge $next
    }
}

# TODO better message on incompatible signature (see above)
def execute-after [items: list]: record -> nothing {
    let context = $in
    for item in $items {
        $context | do $item.execute
    }
}

def format_error [error: record]: nothing -> list<string> {
    let json = $error.json | from json
    let message = $json.msg
    let help = $json | get help?
    let labels = $json | get labels?

    if $help != null {
        [$message, $help]
    } else if ($labels != null) {
        let detail = $labels | each { |label|
            | get text
            # Not sure why this is in the middle of the error json...
            | str replace --all "originates from here" ''
        } | str join "\n"

        if ($message | str contains "Assertion failed") {
            let formatted = ($detail
                | str replace --all --regex '\n[ ]+Left' "\n|>Left"
                | str replace --all --regex '\n[ ]+Right' "\n|>Right"
                | str replace --all --regex '[\n\r]+' ''
                | str replace --all "|>" "\n|>") | str join ""
            [$message, ...($formatted | lines)]
         } else {
            [$message, ...($detail | lines)]
         }
    } else {
        [$message]
    }
}

# Keep a reference to the internal print command
alias print-internal = print

# Override the print command to provide context for output
def print [--stderr (-e), --raw (-r), --no-newline (-n), ...rest: string] {
    let type = if $stderr { "error" } else { "output" }
    emit $type { lines: ($rest | flatten) }
}

def emit [type: string, payload: record] {
    let event = {
        timestamp: (date now | format date "%+")
        suite: $env.NU_TEST_SUITE_NAME?
        test: $env.NU_TEST_NAME?
        type: $type
        payload: $payload
    }
    let packet = $event | to nuon
    print-internal $packet
}
