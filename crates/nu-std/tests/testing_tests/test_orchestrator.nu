use std/assert
use ../../std/testing/orchestrator.nu [
    create-suite-plan-data
    run-suites
]
use ../../std/testing/db.nu
use ../../std/testing/reporter_table.nu

#[test]
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

#[before-each]
def setup []: nothing -> record {
    let temp = mktemp --tmpdir --directory

    let reporter = reporter_table create
    do $reporter.start

    {
        temp: $temp
        reporter: $reporter
    }
}

#[after-each]
def cleanup [] {
    let context = $in

    rm --recursive $context.temp
    do $context.reporter.complete
}

#[test]
def run-suite-with-no-tests [] {
    let context = $in
    let reporter = $context.reporter
    let temp = $context.temp
    let test_file = $temp | path join "test.nu"
    touch $test_file

    let suites = [{name: "test", path: $test_file, tests: []}]
    $suites | run-suites $reporter

    assert equal (do $reporter.results) []
}

#[test]
def run-suite-with-passing-test [] {
    let context = $in
    let reporter = $context.reporter
    let temp = $context.temp

    let suite = "assert equal 1 1" | create-single-test-suite $temp "passing-test"
    let suites = [{ name: $suite.name, path: $suite.path, tests: $suite.tests }]
    $suites | run-suites $reporter

    assert equal (do $reporter.results) [
        {
            suite: "passing-test"
            test: "passing-test"
            result: "PASS"
            output: ""
            error: ""
        }
    ]
}

#[test]
def run-suite-with-ignored-test [] {
    let context = $in
    let reporter = $context.reporter
    let temp = $context.temp

    mut suite = create-suite $temp "suite"
    let suite = "assert equal 1 2" | append-test $temp $suite "ignored-test" --type "ignore"
    [ $suite ] | run-suites $reporter

    assert equal (do $reporter.results) [
        {
            suite: "suite"
            test: "ignored-test"
            result: "SKIP"
            output: ""
            error: ""
        }
    ]
}

#[test]
def run-suite-with-broken-test [] {
    let context = $in
    let reporter = $context.reporter
    let temp = $context.temp

    let test_file = $temp | path join "broken-test.nu"
    "def broken-test" | save $test_file # Parse error
    let tests = [{ name: "broken-test", type: "test" }]
    let suites = [{ name: "suite", path: $test_file, tests: $tests }]
    $suites | run-suites $reporter

    assert equal (do $reporter.results | reject error) [
        {
            suite: "suite"
            test: "broken-test"
            result: "FAIL"
            output: ""
        }
    ]

    let error = do $reporter.results | get error | first
    assert str contains $error "Missing required positional argument"
}

#[test]
def run-suite-with-missing-test [] {
    let context = $in
    let reporter = $context.reporter
    let temp = $context.temp

    let test_file = $temp | path join "missing-test.nu"
    touch $test_file
    let tests = [{ name: "missing-test", type: "test" }]
    let suites = [{ name: "test-suite", path: $test_file, tests: $tests }]
    $suites | run-suites $reporter

    assert equal (do $reporter.results | reject error) [
        {
            suite: "test-suite"
            test: "missing-test"
            result: "FAIL"
            output: ""
        }
    ]

    let error = do $reporter.results | get error | first
    assert str contains $error "`missing-test` is neither a Nushell built-in or a known external command"
}

#[test]
def run-suite-with-failing-test [] {
    let context = $in
    let reporter = $context.reporter
    let temp = $context.temp

    let suite = "assert equal 1 2" | create-single-test-suite $temp "failing-test"
    let suites = [{ name: $suite.name, path: $suite.path, tests: $suite.tests }]
    $suites | run-suites $reporter

    assert equal (do $reporter.results | reject error) [
        {
            suite: $suite.name
            test: "failing-test"
            result: "FAIL"
            output: ""
        }
    ]

    let error = do $reporter.results | get error | first
    assert str contains $error "Assertion failed."
    assert str contains $error "These are not equal."
}

#[test]
def run-suite-with-multiple-tests [] {
    let context = $in
    let reporter = $context.reporter
    let temp = $context.temp

    mut suite = create-suite $temp "multi-test"
    let suite = "assert equal 1 1" | append-test $temp $suite "test1"
    let suite = "assert equal 1 2" | append-test $temp $suite "test2"
    [ $suite ] | run-suites $reporter

    assert equal (do $reporter.results | reject error) [
        {
            suite: "multi-test"
            test: "test1"
            result: "PASS"
            output: ""
        }
        {
            suite: "multi-test"
            test: "test2"
            result: "FAIL"
            output: ""
        }
    ]
}

#[test]
def run-multiple-suites [] {
    let context = $in
    let reporter = $context.reporter
    let temp = $context.temp

    mut suite1 = create-suite $temp "suite1"
    let suite1 = "assert equal 1 1" | append-test $temp $suite1 "test1"
    let suite1 = "assert equal 1 2" | append-test $temp $suite1 "test2"
    mut suite2 = create-suite $temp "suite2"
    let suite2 = "assert equal 1 1" | append-test $temp $suite2 "test3"
    let suite2 = "assert equal 1 2" | append-test $temp $suite2 "test4"

    [$suite1, $suite2] | run-suites $reporter

    assert equal (do $reporter.results | reject error) [
        { suite: "suite1", test: "test1", result: "PASS", output: "" }
        { suite: "suite1", test: "test2", result: "FAIL", output: "" }
        { suite: "suite2", test: "test3", result: "PASS", output: "" }
        { suite: "suite2", test: "test4", result: "FAIL", output: "" }
    ]
}

def create-single-test-suite [temp: string, test: string]: string -> record {
    let suite = create-suite $temp $test
    $in | append-test $temp $suite $test
}

def create-suite [temp: string, suite: string]: nothing -> record {
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

def append-test [temp: string, suite: record, test: string, --type: string = "test"]: string -> record {
    let path = $temp | path join $"($suite.name).nu"

    $"
        def ($test) [] {
            ($in)
        }
    " | save --append $path

    $suite | merge {
        tests: ($suite.tests | append { name: $test, type: $type })
    }
}
