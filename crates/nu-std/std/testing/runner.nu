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

def run-suites [suites: table<name: string, path: string, tests: table<name: string, type: string>>] -> table<name: string, results: table<name: string, result: bool, output: string, error: record<msg: string, debug: string>> {
    $suites | each { |suite| run-suite $suite.name $suite.path $suite.tests }
}

def run-suite [name: string, path: string, tests: table<name: string, type: string>] -> record<name: string, results: table<name: string, result: bool, output: string, error: record<msg: string, debug: string>> {
    let plan_data = create-suite-plan-data $tests

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"source std/testing/runner_embedded.nu; source ($path); plan-execute-suite ($plan_data) | to nuon"
    ) | complete

    # todo success/failure of the plan-execute-suite command (exit code)

    print $result

    let data = $result.stdout | from nuon
    print $data
    {
        name: $name
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
        validate-test-plan
        run-suite-with-no-tests $temp
        run-suite-with-passing-test $temp
        run-suite-with-failing-test $temp
        run-suite-with-multiple-tests $temp
        run-multiple-suites $temp

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

    let result = run-suite "test" $test_file []

    assert equal $result {
        name: "test"
        results: []
    }
}

# [test]
def run-suite-with-passing-test [temp: string] {
    let suite = "assert equal 1 1" | create-single-test-suite $temp "passing-test"

    let result = run-suite $suite.name $suite.path $suite.tests

    assert equal $result {
        name: "passing-test"

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
    let suite = "assert equal 1 2" | create-single-test-suite $temp "failing-test"

    let result = run-suite $suite.name $suite.path $suite.tests

    assert equal ($result | reject results.error) {
        name: "failing-test"

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

# [test]
def run-suite-with-multiple-tests [temp: string] {
    mut suite = create-suite $temp "multi-test"
    let suite = "assert equal 1 1" | append-test $temp $suite "test1"
    let suite = "assert equal 1 2" | append-test $temp $suite "test2"

    let result = run-suite $suite.name $suite.path $suite.tests

    assert equal ($result | reject results.error) {
        name: "multi-test"

        results: [
            {
                name: "test1"
                success: true
                output: ""
            }
            {
                name: "test2"
                success: false
                output: ""
            }
        ]
    }
}

# [test]
def run-multiple-suites [temp: string] {
    mut suite1 = create-suite $temp "suite1"
    let suite1 = "assert equal 1 1" | append-test $temp $suite1 "test1"
    let suite1 = "assert equal 1 2" | append-test $temp $suite1 "test2"
    mut suite2 = create-suite $temp "suite2"
    let suite2 = "assert equal 1 1" | append-test $temp $suite2 "test3"
    let suite2 = "assert equal 1 2" | append-test $temp $suite2 "test4"

    let result = run-suites [$suite1, $suite2]

    assert equal ($result | reject results.error) [
        {
            name: "suite1"
            results: [
                { name: "test1", success: true, output: "" }
                { name: "test2", success: false, output: "" }
            ]
        }
        {
            name: "suite2"
            results: [
                { name: "test3", success: true, output: "" }
                { name: "test4", success: false, output: "" }
            ]
        }
    ]
}

def create-single-test-suite [temp: string, test: string]: string -> record {
    let suite = create-suite $temp $test
    $in | append-test $temp $suite $test
}

def create-suite [temp: string, suite: string] -> record {
    let path = $temp | path join $"($suite).nu"

    $"
        use std/assert
    " | save $path

    {
        name: $suite
        path: $path
        tests: []
    }
}

def append-test [temp: string, suite: record, test: string]: string -> record {
    let path = $temp | path join $"($suite.name).nu"

    $"
        def ($test) [] {
            ($in)
        }
    " | save --append $path

    $suite | merge {
        tests: ($suite.tests | append { name: $test, type: "test" })
    }
}

def trim []: string -> string {
    $in | str replace --all --regex '[\n\r ]+' ' '
}

