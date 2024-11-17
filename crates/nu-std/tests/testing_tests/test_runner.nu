use std/assert
use ../../std/testing/runner.nu [
    create-suite-plan-data
    run-suite
    run-suites
]

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

def trim []: string -> string {
    $in | str replace --all --regex '[\n\r ]+' ' '
}

# [before-each]
def setup [] -> record {
    let temp = mktemp --tmpdir --directory
    {
        temp: $temp
    }
}

# [after-each]
def cleanup [] {
    let context = $in
    rm --recursive $context.temp
}

# [test]
def run-suite-with-no-tests [] {
    let context = $in
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
                error: ""
                failure: null
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

    assert equal ($result | reject results.failure) {
        name: "suite"

        results: [
            {
                name: "broken-test"
                success: false
                output: ""
                error: ""
            }
        ]
    }

    let error = $result.results | get failure | first
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

    assert equal ($result | reject results.failure) {
        name: "test"

        results: [
            {
                name: "missing-test"
                success: false
                output: ""
                error: ""
            }
        ]
    }

    let error = $result.results | get failure | first
    assert str contains $error "Command `missing-test` not found"
}

# [test]
def run-suite-with-failing-test [] {
    let context = $in
    let $temp = $context.temp

    let suite = "assert equal 1 2" | create-single-test-suite $temp "failing-test"

    let result = run-suite $suite.name $suite.path $suite.tests

    assert equal ($result | reject results.failure) {
        name: "failing-test"

        results: [
            {
                name: "failing-test"
                success: false
                output: ""
                error: ""
            }
        ]
    }

    let error = $result.results | get failure | first
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

    assert equal ($result | reject results.failure) {
        name: "multi-test"

        results: [
            {
                name: "test1"
                success: true
                output: ""
                error: ""
            }
            {
                name: "test2"
                success: false
                output: ""
                error: ""
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

    assert equal ($result | reject results.failure) [
        {
            name: "suite1"
            results: [
                { name: "test1", success: true, output: "", error: ""}
                { name: "test2", success: false, output: "", error: "" }
            ]
        }
        {
            name: "suite2"
            results: [
                { name: "test3", success: true, output: "", error: "" }
                { name: "test4", success: false, output: "", error: "" }
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
