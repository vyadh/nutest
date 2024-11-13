use std/assert

# This script generates the test suite data and embeds a runner into a nushell sub-process to execute.

# INPUT DATA STRUCTURES
#
# test:
# {
#     name: string
#     type: string
# }
#
# suite:
# {
#     name: string
#     path: string
#     tests: list<test>
# }
#
# OUTPUT DATA STRUCTURES
#
# test-result:
# {
#     name: string
#     result: bool
#     output: string
#     error: record<msg: string, debug: string>
# }
#
# suite-result:
# {
#     name: string
#     results: list<test-result>
# }

# TODO - Move all tests to main test dir

#suites: table<name: string, path: string, tests: table<name: string, type: string>>
export def run-suites [suites: list] -> table<name: string, results: table<name: string, result: bool, output: string, error: record<msg: string, debug: string>> {
    $suites | par-each { |suite| run-suite $suite.name $suite.path $suite.tests }
}

export def run-suite [name: string, path: string, tests: table<name: string, type: string>] -> record<name: string, results: table<name: string, result: bool, output: string, error: record<msg: string, debug: string>> {
    let plan_data = create-suite-plan-data $tests

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"source std/testing/runner_embedded.nu; source ($path); plan-execute-suite ($plan_data) | to nuon"
    ) | complete

    let test_results = if $result.exit_code == 0 { # todo filter to tests only
        # TODO required to output `print -e` usage in tests
        #print -e $result.stderr
        $result.stdout | from nuon
    } else {
        # This is only triggered on a suite-level failure not caught by the embedded runner
        # Replicate this suite-level failure for every test
        $tests | each { |test|
            {
                name: $test.name
                success: false
                output: ""
                error: $result.stderr
            }
        }

    }

    {
        name: $name
        results: $test_results
    }
}

export def create-suite-plan-data [tests: table<name: string, type: string>] -> string {
    let plan_data = $tests
            | each { |test| create-test-plan-data $test }
            | str join ", "

    $"[ ($plan_data) ]"
}

def create-test-plan-data [test: record<name: string, type: string>] -> string {
    $'{ name: "($test.name)", type: "($test.type)", execute: { ($test.name) } }'
}
