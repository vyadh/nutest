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

# Note: The below commands are prefixed to avoid conflicts with test files.

export def nutest-299792458-execute-suite [suite: string, threads: int, suite_data: list] {
    with-env { NU_TEST_SUITE_NAME: $suite } {
        nutest-299792458-execute-suite-internal $threads $suite_data
    }

    # Don't output any result
    null
}

def nutest-299792458-execute-suite-internal [threads: int, suite_data: list] {
    let plan = $suite_data | group-by type

    def get-or-empty [key: string]: list -> list {
        $in | get --ignore-errors $key | default []
    }

    let before_all = $plan | get-or-empty "before-all"
    let before_each = $plan | get-or-empty "before-each"
    let after_each = $plan | get-or-empty "after-each"
    let after_all = $plan | get-or-empty "after-all"
    let tests = $plan | get-or-empty "test"
    let ignored = $plan | get-or-empty "ignore"

    # TODO test exception handling
    let context_all = { } | nutest-299792458-execute-before $before_all

    $tests | par-each --threads $threads { |test|
        # Allow print output to be associated with specific tests by adding name to the environment
        with-env { NU_TEST_NAME: $test.name } {
            nutest-299792458-emit "start" { }

            # TODO clean this up a bit
            try {
                let context = $context_all | nutest-299792458-execute-before $before_each

                try {
                    $context | do $test.execute
                    $context | nutest-299792458-execute-after $after_each # TODO if throws, will exec again
                    nutest-299792458-emit "result" { status: "PASS" }
                } catch { |error|
                    nutest-299792458-emit "result" { status: "FAIL" }
                    print -e ...(nutest-299792458-format-error $error)
                    # TODO test exception handling, since this should still run
                    $context | nutest-299792458-execute-after $after_each
                }

            } catch { |error|
                nutest-299792458-emit "result" { status: "FAIL" }
                print -e ...(nutest-299792458-format-error $error)
                # TODO test exception handling, since this should still run
                $context_all | nutest-299792458-execute-after $after_each
            }

            nutest-299792458-emit "finish" { }
        }
    }

    for test in $ignored {
        with-env { NU_TEST_NAME: $test.name } {
            nutest-299792458-emit "start" { }
            nutest-299792458-emit "result" { status: "SKIP" }
            nutest-299792458-emit "finish" { }
        }
    }

    # TODO test exception handling
    $context_all | nutest-299792458-execute-after $after_all
}

# TODO better message on incompatible signature where we don't supply the context
#   not: expected: input, and argument, to be both record or both
def nutest-299792458-execute-before [items: list]: record -> record {
    let initial_context = $in
    $items | reduce --fold $initial_context { |it, acc|
        let next = (do $it.execute)
        $acc | merge $next
    }
}

# TODO better message on incompatible signature (see above)
def nutest-299792458-execute-after [items: list]: record -> nothing {
    let context = $in
    for item in $items {
        $context | do $item.execute
    }
}

def nutest-299792458-format-error [error: record]: nothing -> list<string> {
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
alias nutest-299792458-print = print

# Override the print command to provide context for output
def print [--stderr (-e), --raw (-r), --no-newline (-n), ...rest: string] {
    let type = if $stderr { "error" } else { "output" }
    nutest-299792458-emit $type { lines: ($rest | flatten) }
}

def nutest-299792458-emit [type: string, payload: record] {
    let event = {
        timestamp: (date now | format date "%+")
        suite: $env.NU_TEST_SUITE_NAME?
        test: $env.NU_TEST_NAME?
        type: $type
        payload: $payload
    }
    let packet = $event | to nuon
    nutest-299792458-print $packet
}
