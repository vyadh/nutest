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
# suite_results:
# [
#      {
#          name: string
#          success: bool
#          output: string
#          error: string
#          failure: record<msg: string, debug: string>
#      }
# ]
#
# Where:
#   `type` can be "test", "before-all", etc.
#   `execute` is the closure function of `type`
#

# TODO - Rename runner?

def main2 [] {
    const success_message = "I'd much rather be happy than right any day"
    const warning_message = "Don't Panic"
    const failure_message = "No tea"

    def success [] {
        print $success_message
    }
    def warning [] { print -e $warning_message }
    def failure [] { error make { msg: $failure_message } }

    let plan = [
        { name: "test_success", type: "test", execute: { success } }
        { name: "test_warning", type: "test", execute: { warning } }
        { name: "test_failure", type: "test", execute: { failure } }
    ]

    emit "testing" {name: 'escape "}'}
    print "foo" "bar"
    plan-execute-suite-emit "some-suite" $plan
}

# TODO prefix commands with something unusual to avoid conflicts

export def plan-execute-suite-emit [$suite: string, suite_data: list] {
    with-env { NU_TEST_SUITE_NAME: $suite } {
        emit "suite-start" { }
        plan-execute-suite $suite_data
        emit "suite-end" {}
    }
}

# TODO - Add support for: before-all, after-all
def plan-execute-suite [suite_data: list] {
    let plan = $suite_data | group-by type
    let before_each = $plan | get --ignore-errors "before-each" | default []
    let after_each = $plan | get --ignore-errors "after-each" | default []
    let tests = $plan | get --ignore-errors "test" | default []

    let results = $tests | each { |test|
        # Allow print output to be associated with specific tests by adding name to the environment
        with-env { NU_TEST_NAME: $test.name } {
            # TODO put try here?
            emit "test-begin" { }
            let context = execute-before $before_each
            let result = execute-test $context $test.name $test.execute
            $context | execute-after $after_each
            emit "test-end" { }
            $result
        }
    }
}

#  TODO capture out/err
def execute-before [items: list] -> record {
    # TODO test failure handling
    try {
        $items | reduce --fold {} { |item, acc|
            $acc | merge (do $item.execute)
        }
    } catch { |error|
        print -e $error
        {}
    }
}

#  TODO capture out/err
def execute-after [items: list] {
    # TODO test failure handling
    try {
        let context = $in
        $items | each { |item|
            let execute = $item.execute
            $context | do $execute
        }
    } catch { |error|
        print -e $error
    }
}

def execute-test [context: record, name: string, execute: closure] -> record {
    try {
        $context | do $execute
        emit "result" { success: true }
    } catch { |error|
        emit "result" { success: false }
        print -e (format_error $error)
        # TODO - Capture error output?
    }
}

def format_error [error: record] -> string {
    let json = $error.json | from json
    let message = $json.msg
    let help = $json | get help?
    let labels = $json | get labels?

    if $help != null {
        $"($message)\n($help)"
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
            $"(ansi red)($message)(ansi reset)\n($formatted)"
         } else {
            $"($message)($detail)"
         }
    } else {
        $message
    }
}

# Keep a reference to the internal print command
alias print-internal = print

# Override the print command to provide context for output
def print [--stderr (-e), --raw (-r), --no-newline (-n), ...rest: string] {
    let type = if $stderr { "error" } else { "output" }
    emit $type { lines: $rest }
}

def emit [type: string, payload: record] {
    let event = {
        timestamp: (date now | format date "%+")
        suite: $env.NU_TEST_SUITE_NAME?
        test: $env.NU_TEST_NAME?
        type: $type
        payload: $payload
    }
    print-internal $"($event | to nuon)"
}
