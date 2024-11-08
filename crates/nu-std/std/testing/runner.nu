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


# tests: table<name: string, type: string>
def run-suite [suite: record<name: string, path: string, tests: list>] -> record<name: string, results: table<name: string, result: bool, output: string, error: record<msg: string, debug: string>> {
    let plan_data = create-suite-plan-data $suite.tests

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"source std/testing/runner_embedded.nu; source ($suite.path); plan-execute-suite ($plan_data) | to nuon"
    ) | complete

    # todo success/failure of the plan-execute-suite command (exit code)

    print $result

    let data = $result.stdout | from nuon
    print $data
    {
        name: $suite.name
        results: $data
    }

    #let results = $suite.tests | each { run-test $in }
    #{
    #    name: $suite.name
    #    results: $results
    #}
}

# subshell context
#def run-test [test: record<name: string, type: string>] -> record<name: string, result: bool, output: string, error: record<msg: string, debug: string>> {
#    try {
#        print $"Running: ($test.name)"
#        do { $test.name }
#        { name: $test.name, result: true, output: "", error: { msg: "", debug: "" } }
#    } catch { |error|
#        { name: $test.name, result: false, output: "", error: { msg: $error.msg, debug: $error.debug } }
#    }
#}

def create-suite-plan-data [tests: table<name: string, type: string>] -> string {
    let plan_data = $tests
            | each { |test| create-test-plan-data $test }
            | str join ", "

    $"[ ($plan_data) ]"
}

def create-test-plan-data [test: record<name: string, type: string>] -> string {
    $'{ name: "($test.name)", type: "($test.type)", execute: { ($test.name) } }'
}


def main [] {
    let temp = mktemp --tmpdir --directory
    try {
        #validate-test-plan
        #run-suite-with-no-tests $temp
        run-suite-with-passing-test $temp
        run-suite-with-failing-test $temp

        rm --recursive $temp
    } catch { |e|
        rm --recursive $temp
        $e.raw # rethrow error
    }
}

# [test]
def validate-test-plan [] {
    let tests = [
        { name: "test_a", type: "test" }
        { name: "test_b", type: "test" }
        { name: "setup", type: "before-all" }
        { name: "cleanup", type: "after-each" }
    ]

    let plan = create-suite-plan-data $tests

    assert equal $plan ('[
        { name: "test_a", type: "test", execute: { test_a } },
        { name: "test_b", type: "test", execute: { test_b } },
        { name: "setup", type: "before-all", execute: { setup } },
        { name: "cleanup", type: "after-each", execute: { cleanup } }
    ]' | trim)
}

# [test]
def run-suite-with-no-tests [temp: string] {
    let test_file = $temp | path join "test.nu"
    touch $test_file

    let suite = {
        name: "test"
        path: $test_file
        tests: []
    }

    let result = run-suite $suite

    assert equal $result {
        name: "test"
        results: []
    }
}

# [test]
def run-suite-with-passing-test [temp: string] {
    let suite = "assert equal 1 1" | create-test-suite $temp "passing-test"

    let result = run-suite $suite

    assert equal $result {
        name: "suite"

        results: [
            {
                name: "passing-test"
                success: true
                output: ""
                error: null
            }
        ]
    }
}

# [test]
def run-suite-with-failing-test [temp: string] {
    let suite = "assert equal 1 2" | create-test-suite $temp "failing-test"

    let result = run-suite $suite

    assert equal ($result | reject results.error) {
        name: "suite"

        results: [
            {
                name: "failing-test"
                success: false
                output: ""
            }
        ]
    }

    let error = $result.results | get error | first
    assert str contains $error "Assertion failed."
    assert str contains $error "These are not equal."
}

def create-test-suite [temp: string, test_name: string]: string -> record {
    let path = $temp | path join $"($test_name).nu"

    $"
        use std/assert
        def ($test_name) [] {
            ($in)
        }
    " | save $path

    {
        name: "suite"
        path: $path
        tests: [
            { name: $test_name, type: "test" }
        ]
    }
}

def trim []: string -> string {
    $in | str replace --all --regex '[\n\r ]+' ' '
}

