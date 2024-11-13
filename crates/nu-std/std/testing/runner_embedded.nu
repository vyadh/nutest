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
#          error: record<msg: string, debug: string>
#      }
# ]
#
# Where:
#   `type` can be "test", "before-all", etc.
#   `execute` is the closure function of `type`
#

use std log

# TODO - Add support for: before-all, after-all
# TODO - Std output/error not reflected in the test results (capture issue)
# TODO - Document `print` breaking of tests and should use `print -e`
export def plan-execute-suite [suite_data: list] -> table<name, success, output, error> {
    let before_each_items = $suite_data | items-with-type "before-each"
    let after_each_items = $suite_data | items-with-type "after-each"
    let tests = $suite_data | items-with-type "test"

    let results = $tests | each { |test|
        let context = execute-before $before_each_items
        let result = execute-test $context $test.name $test.execute
        $context | execute-after $after_each_items
        $result
    }

    $results
}

def items-with-type [type: string] {
    $in | where ($it.type == $type)
}

def execute-before [items: list] -> record {
    # TODO failure handling
    $items | reduce --fold {} { |item, acc|
        $acc | merge (do $item.execute)
    }
}

def execute-after [items: list] {
    # TODO failure handling
    let context = $in
    $items | each { |item|
        let execute = $item.execute
        $context | do $execute
    }
}

def execute-test [context: record, name: string, execute: closure] {
    try {
        # TODO what to do with result of this?
        $context | do $execute
        {
            name: $name
            success: true
            output: ""
            error: null
        }
    } catch { |error|
        {
            name: $name
            success: false
            output: ""
            error: (format_error $error.debug)
        }
    }
}

def format_error [error: string] {
    # Get the text from errors like: GenericError { error: "Error message" }
    let error_generic = $error | parse --regex 'error: "(?<error>[^"]+)"'
    if ($error_generic | is-not-empty) {
        return ($error_generic | first | get error)
    }

    # Get the text from errors like: LabeledError(LabeledError { msg: "Assertion failed.", labels: [ErrorLabel { text: "These are not equal...
    let error_label = $error | parse --regex 'msg: "(?<msg>[^"]+).+text: "(?<text>.+)'
    if ($error_label | is-not-empty) {
        return $"($error_label | first | get msg) ($error_label | first | get text)"
    }

    # Anything else
    $error
}

#export def ($test_function_name) [] {
#    ($test.before-each)
#    try {
#        $context | ($test.test)
#        ($test.after-each)
#    } catch { |err|
#        ($test.after-each)
#        $err | get raw
#    }
#}
