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

export def plan-execute-suite-emit [$suite: string, suite_data: list] {
    with-env { NU_TEST_SUITE_NAME: $suite } {
        plan-execute-suite $suite_data
    }

    # Don't output any result
    null
}

# TODO - Add support for: before-all, after-all
def plan-execute-suite [suite_data: list] {
    let plan = $suite_data | group-by type
    let before_each = $plan | get --ignore-errors "before-each" | default []
    let after_each = $plan | get --ignore-errors "after-each" | default []
    let tests = $plan | get --ignore-errors "test" | default []

    $tests | each { |test|
        # Allow print output to be associated with specific tests by adding name to the environment
        with-env { NU_TEST_NAME: $test.name } {
            emit "start" { }
            try {
                let context = execute-before $before_each
                let result = $context | do $test.execute
                $context | execute-after $after_each
                emit "result" { status: "PASS" }
            } catch { |error|
                emit "result" { status: "FAIL" }
                print -e ...(format_error $error)
            }
            emit "finish" { }
        }
    }

    let ignored = $plan | get --ignore-errors "ignore" | default []
    $ignored | each { |test|
        with-env { NU_TEST_NAME: $test.name } {
            emit "start" { }
            emit "result" { status: "SKIP" }
            emit "finish" { }
        }
    }
}

# TODO better message on incompatible signature
def execute-before [items: list]: nothing -> record {
    $items | reduce --fold {} { |item, acc|
        $acc | merge (do $item.execute)
    }
}

# TODO better message on incompatible signature
def execute-after [items: list] {
    let context = $in
    $items | each { |item|
        let execute = $item.execute
        $context | do $execute
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
            [$"(ansi red)($message)(ansi reset)", ...($formatted | lines)]
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
