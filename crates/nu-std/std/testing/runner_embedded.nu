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

# TODO - Add support for: before-all, after-all
export def plan-execute-suite [suite_data: list] -> table<name, success, output, error, failure> {
    nu-test-db-create

    # TODO group by type
    let before_each_items = $suite_data | items-with-type "before-each"
    let after_each_items = $suite_data | items-with-type "after-each"
    let tests = $suite_data | items-with-type "test"

    let results = $tests | each { |test|
        # Allow print output to be associated with specific tests by adding name to the environment
        with-env { NU_TEST_NAME: $test.name } {
            let context = execute-before $before_each_items
            let result = execute-test $context $test.name $test.execute
            $context | execute-after $after_each_items
            $result
        }
    }

    $results
}

def items-with-type [type: string] {
    $in | where ($it.type == $type)
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
        # TODO what to do with result of this?
        $context | do $execute
        {
            name: $name
            success: true
            output: (nu-test-db-query $name "output")
            error: (nu-test-db-query $name "error")
            failure: null
        }
    } catch { |error|
        {
            name: $name
            success: false
            output: (nu-test-db-query $name "output")
            error: (nu-test-db-query $name "error")
            failure: (format_error $error)
        }
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

# Overriding the print command to capture and return test output
# TODO test sql injection
def print [--stderr (-e), --raw (-r), --no-newline (-n), ...rest: string] {
    let test = $env.NU_TEST_NAME
    let type = if $stderr { "error" } else { "output" }
    let message = $rest | str join '\n'
    let row = { test: $test, type: $type, message: $message }
    $row | stor insert --table-name nu_test_prints
}

def nu-test-db-create [] {
    stor create --table-name nu_test_prints --columns {
        test : str
        type : str
        message : str
    }
}

# We close the db so tests of this do not open the db multiple times
def nu-test-db-close [] {
    stor delete --table-name nu_test_prints
}

def nu-test-db-query [test: string, type: string] -> string {
    (
        stor open
            | query db $"
                SELECT message
                FROM nu_test_prints
                WHERE test = :test AND type = :type
            " --params { test: $test, type: $type }
            | get message
            | str join "\n"
    )
}
