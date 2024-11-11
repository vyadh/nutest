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

# TODO - Move all tests to main test dir
# TODO - Add support for before-all, after-all, before-each, after-each

def plan-execute-suite [suite_data: list] -> table<name, success, output> {
    #print -e "planning"
    #print -e $suite_data

    #print -e "executing"
    let results = $suite_data
        | where ($it.type == "test")
        | each { |test| execute-test $test.name $test.execute }

    #print -e "results" $results
    #print -e "return"
    $results
}

def execute-test [name: string, execute: closure] {
    try {
        let result = (do $execute)
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
            error: $error.debug
        }
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
