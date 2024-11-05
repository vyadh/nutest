#!/usr/bin/env nu
use std assert

# Usage:
#   cd crates/nu-std
#   nu -c "source bstest.nu; source <test-file>.nu; run-all-tests <test-file>.nu"
#   nu -c "source std/testing/bstest.nu; source tests/testing_tests/test_discover.nu; run-all-tests tests/testing_tests/test_discover.nu"

def run-all-tests [file: string] {
    let test_plan = (
        scope commands
            | where ($it.type == "custom")
                and ($it.description | str starts-with "[test]")
                and not ($it.description | str starts-with "ignore")
            | each { |test| create_execution_plan $test.name }
            | str join ", "
    )
    let plan = $"run_tests [ ($test_plan) ]"
    ^$nu.current-exe --commands $"source std/testing/bstest.nu; source ($file); ($plan)"
}

def create_execution_plan [test: string] -> string {
    $"{ name: \"($test)\", execute: { ($test) } }"
}

def run_tests [tests: list<record<name: string, execute: closure>>] {
    let results = $tests | par-each { run_test $in }

    print_results $results
    print_summary $results

    if ($results | any { |test| $test.result == "FAIL" }) {
        exit 1
    }
}

def print_results [results: list<record<name: string, result: string>>] {
    let display_table = $results | update result { |row|
        let emoji = if ($row.result == "PASS") { "✅" } else { "❌" }
        $"($emoji) ($row.result)"
    }

    if ("GITHUB_ACTIONS" in $env) {
        print ($display_table | to md --pretty)
    } else {
        print $display_table
    }
}

def print_summary [results: list<record<name: string, result: string>>] -> bool {
    let success = $results | where ($it.result == "PASS") | length
    let failure = $results | where ($it.result == "FAIL") | length
    let count = $results | length

    if ($failure == 0) {
        print $"\nTesting completed: ($success) of ($count) were successful"
    } else {
        print $"\nTesting completed: ($failure) of ($count) failed"
    }
}

def run_test [test: record<name: string, execute: closure>] -> record<name: string, result: string, error: string> {
    try {
        do ($test.execute)
        { result: $"PASS",name: $test.name, error: "" }
    } catch { |error|
        { result: $"FAIL", name: $test.name, error: $"($error.msg) ($error.debug)" }
    }
}

def format_error [error: string] {
    $error
        # Get the value for the text key in a partly non-json error message
        | parse --regex ".+text: \"(.+)\""
        | first
        | get capture0
        | str replace --all --regex "\\\\n" " "
        | str replace --all --regex " +" " "
}
