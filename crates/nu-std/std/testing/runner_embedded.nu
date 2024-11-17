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
            failure: (format_error $error.debug)
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
