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

#[before-all]
# Since we only have one database it needs to be created once before all tests.
# We also need to ensure we narrow down results to the unique ones used in each test.
def setup-db []: nothing -> record {
    "\nsetup-db" | save -a $"z.test"

    let reporter = reporter_table create
    do $reporter.start

    {
        reporter: $reporter
    }
}

#[before-each]
def setup-temp-dir []: nothing -> record {
    let temp = mktemp --tmpdir --directory

    {
        temp: $temp
    }
}

#[after-each]
def cleanup [] {
    #print $"exporting (date now | format date '%+')"
    #print $"(pwd)"
    let context = $in
    rm --recursive $context.temp
}

#[after-all]
def delete-db [] {
    #print $"(date now | format date '%+')"
    #print $"exporting (date now | format date '%+')"
    #"test" | save -a $"z-(date now | format date '%+' | str replace --all ':' '-')-(random chars --length 1)-2.test"
    #stor export --file-name $"(date now | format date '%+' | str replace --all ':' '-')(random chars --length 4)-.sqlite"
    stor export --file-name $"C:/dev/nu-test/crates/nu-std/zdb-(date now | format date '%+' | str replace --all ':' '-')-(random chars --length 4).sqlite"
    #print $"exported"

    let reporter = $in.reporter
    do $reporter.complete
    print $"exported2"

    "\ndelete-db" | save -a $"z.test"
}

#[test]
def run-suite-with-no-tests [] {
    let context = $in
    let reporter = $context.reporter
    let temp = $context.temp
    let test_file = $temp | path join "test.nu"
    touch $test_file

    let suites = [{name: "none", path: $test_file, tests: []}]
    let results = $suites | test-run $context | reject error

    assert equal $results []
}

#[test]
def run-suite-with-passing-test [] {
    "\n   run-suite-with-passing-test" | save -a $"z.test"

    let context = $in
    let temp = $context.temp

    let suite = "assert equal 1 1" | create-single-test-suite $temp "passing"
    let suites = [{ name: $suite.name, path: $suite.path, tests: $suite.tests }]
    let results = $suites | test-run $context

    assert equal $results [
        {
            suite: "passing"
            test: "passing"
            result: "PASS"
            output: ""
            error: ""
        }
    ]
}

#[test]
def run-suite-with-ignored-test [] {
    let context = $in
    let temp = $context.temp

    mut suite = create-suite $temp "ignored"
    let suites = [ ("assert equal 1 2" | append-test $temp $suite "ignored-test" --type "ignore") ]
    let results = $suites | test-run $context

    assert equal $results [
        {
            suite: "ignored"
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
    let temp = $context.temp

    let test_file = $temp | path join "broken-test.nu"
    "def broken-test" | save $test_file # Parse error
    let tests = [{ name: "broken-test", type: "test" }]
    let suites = [{ name: "broken", path: $test_file, tests: $tests }]
    let results = $suites | test-run $context

    assert equal ($results | reject error) [
        {
            suite: "broken"
            test: "broken-test"
            result: "FAIL"
            output: ""
        }
    ]

    let error = $results | get error | first
    assert str contains $error "Missing required positional argument"
}

#[test]
def run-suite-with-missing-test [] {
    let context = $in
    let temp = $context.temp

    let test_file = $temp | path join "missing-test.nu"
    touch $test_file
    let tests = [{ name: "missing-test", type: "test" }]
    let suites = [{ name: "missing", path: $test_file, tests: $tests }]
    let results = $suites | test-run $context

    assert equal ($results | reject error) [
        {
            suite: "missing"
            test: "missing-test"
            result: "FAIL"
            output: ""
        }
    ]

    let error = $results | get error | first
    assert str contains $error "`missing-test` is neither a Nushell built-in or a known external command"
}

#[test]
def run-suite-with-failing-test [] {
    let context = $in
    let temp = $context.temp

    let suite = "assert equal 1 2" | create-single-test-suite $temp "failing"
    let suites = [{ name: $suite.name, path: $suite.path, tests: $suite.tests }]
    let results = $suites | test-run $context

    assert equal ($results | reject error) [
        {
            suite: "failing"
            test: "failing"
            result: "FAIL"
            output: ""
        }
    ]

    let error = $results | get error | first
    assert str contains $error "Assertion failed."
    assert str contains $error "These are not equal."
}

#[test]
def run-suite-with-multiple-tests [] {
    let context = $in
    let temp = $context.temp

    mut suite = create-suite $temp "multi"
    let suite = "assert equal 1 1" | append-test $temp $suite "test1"
    let suite = "assert equal 1 2" | append-test $temp $suite "test2"
    let results = [ $suite ] | test-run $context | reject error

    assert equal $results [
        {
            suite: "multi"
            test: "test1"
            result: "PASS"
            output: ""
        }
        {
            suite: "multi"
            test: "test2"
            result: "FAIL"
            output: ""
        }
    ]
}

#[test]
def run-multiple-suites [] {
    let context = $in
    let temp = $context.temp

    mut suite1 = create-suite $temp "suite1"
    let suite1 = "assert equal 1 1" | append-test $temp $suite1 "test1"
    let suite1 = "assert equal 1 2" | append-test $temp $suite1 "test2"
    mut suite2 = create-suite $temp "suite2"
    let suite2 = "assert equal 1 1" | append-test $temp $suite2 "test3"
    let suite2 = "assert equal 1 2" | append-test $temp $suite2 "test4"
    let results = [$suite1, $suite2] | test-run $context | reject error

    assert equal $results ([
        { suite: "suite1", test: "test1", result: "PASS", output: "" }
        { suite: "suite1", test: "test2", result: "FAIL", output: "" }
        { suite: "suite2", test: "test3", result: "PASS", output: "" }
        { suite: "suite2", test: "test4", result: "FAIL", output: "" }
    ] | sort-by suite test)
}

#[test]
def run-test-with-output-and-error-lines [] {
    let context = $in
    let temp = $context.temp

    mut suite = create-suite $temp "output"
    let suites = [ ("print 1 2; print -e 3 4" | append-test $temp $suite "test") ]
    let results = $suites | test-run $context

    assert equal $results [
        {
            suite: "output"
            test: "test"
            result: "PASS"
            output: "1\n2"
            error: "3\n4"
        }
    ]
}


def test-run [context: record] list<record> -> list<record> {
    let suites = $in
    let reporter = $context.reporter

    $"\ntest-run" | save -a $"z.test"
    $suites | run-suites $reporter 1

    let results = do $reporter.results
    $results | where suite in ($suites | get name)
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
