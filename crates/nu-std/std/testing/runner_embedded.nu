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

# TODO - Add support for before-all, after-all, before-each, after-each
# TODO - Figure out what we need to do with print and print -e output
export def plan-execute-suite [suite_data: list] -> table<name, success, output, error> {
    let results = $suite_data
        | where ($it.type == "test")
        | each { |test| execute-test $test.name $test.execute }

    $results
}

def execute-test [name: string, execute: closure] {
    try {
        # TODO what to do with result itself?
        let result = do $execute
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
    let error_text = $error | parse --regex 'error: "(?<error>[^"]+)"'
    if ($error_text | is-not-empty) {
        $error_text | first | get error
    } else {
        $error
    }
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
