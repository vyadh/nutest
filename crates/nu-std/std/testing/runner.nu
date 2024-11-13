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

def run-suite [name: string, path: string, tests: table<name: string, type: string>] -> record<name: string, results: table<name: string, result: bool, output: string, error: record<msg: string, debug: string>> {
    let plan_data = create-suite-plan-data $tests

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"source std/testing/runner_embedded.nu; source ($path); plan-execute-suite ($plan_data) | to nuon"
    ) | complete

    let test_results = if $result.exit_code == 0 { # todo filter to tests only
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





export def main2 [] {
    print "main"
}

def main [] {
    let temp = mktemp --tmpdir --directory
    let context = {
        temp: $temp
    }
    try {
        $context | validate-test-plan
        $context | run-suite-with-missing-test
        $context | run-suite-with-broken-test
        $context | run-suite-with-no-tests
        $context | run-suite-with-passing-test
        $context | run-suite-with-failing-test
        $context | run-suite-with-multiple-tests
        $context | run-multiple-suites

        rm --recursive $temp
    } catch { |e|
        rm --recursive $temp
        $e.raw # rethrow error
    }
}


# [test]
def run-suite-with-no-tests [] {
    let context = $in
    #print -e "START"
    #print -e $context
    #print -e "END"
    let $temp = $context.temp

    let test_file = $temp | path join "test.nu"
    touch $test_file

    let result = run-suite "test" $test_file []

    assert equal $result {
        name: "test"
        results: []
    }
}

# [test]
def run-suite-with-passing-test [] {
    let context = $in
    let $temp = $context.temp

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
def run-suite-with-broken-test [] {
    let context = $in
    let $temp = $context.temp

    let test_file = $temp | path join "broken-test.nu"
    "def broken-test" | save $test_file # Parse error
    let tests = [{ name: "broken-test", type: "test" }]
    let result = run-suite "suite" $test_file $tests

    assert equal ($result | reject results.error) {
        name: "suite"

        results: [
            {
                name: "broken-test"
                success: false
                output: ""
            }
        ]
    }

    let error = $result.results | get error | first
    assert str contains $error "Missing required positional argument"
}

# [test]
def run-suite-with-missing-test [] {
    let context = $in
    let $temp = $context.temp

    let test_file = $temp | path join "missing-test.nu"
    touch $test_file
    let tests = [{ name: "missing-test", type: "test" }]

    let result = run-suite "test" $test_file $tests
    #print -e ($result | table --expand)

    assert equal ($result | reject results.error) {
        name: "test"

        results: [
            {
                name: "missing-test"
                success: false
                output: ""
            }
        ]
    }

    let error = $result.results | get error | first
    assert str contains $error "Command `missing-test` not found"
}

# [test]
def run-suite-with-failing-test [] {
    let context = $in
    let $temp = $context.temp

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
def run-suite-with-multiple-tests [] {
    let context = $in
    let $temp = $context.temp

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
def run-multiple-suites [] {
    let context = $in
    let $temp = $context.temp

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
