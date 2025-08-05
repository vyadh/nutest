# Displays test results in the terminal as they are output.

use ../store.nu
use ../theme.nu
use ../formatter.nu

export def create []: nothing -> record<name: string, run-start: closure, run-complete: closure, test-start: closure, test-complete: closure> {
    let theme = theme standard
    let error_format = "rendered"
    let formatter = formatter pretty $theme $error_format

    {
        name: "display terminal"
        run-start: { start-suite }
        run-complete: { complete-suite }
        test-start: { |row| start-test $row }
        test-complete: { |row| $row | complete-test $theme $formatter }
    }
}

def start-suite []: nothing -> nothing {
    print "Running tests..."
}

def complete-suite []: nothing -> nothing {
    let results = store query
    let by_result = $results | group-by result

    let total = $results | length
    let passed = $by_result | count "PASS"
    let failed = $by_result | count "FAIL"
    let skipped = $by_result | count "SKIP"

    let output = $"($total) total, ($passed) passed, ($failed) failed, ($skipped) skipped"
    print $"Test run completed: ($output)"
}

def count [key: string]: record -> int {
    $in
        | get --optional $key
        | default []
        | length
}

def start-test [row: record]: nothing -> nothing {
}

def complete-test [theme: closure, formatter: closure]: record -> nothing {
    let event = $in
    let suite = { type: "suite", text: $event.suite } | do $theme
    let test = { type: "test", text: $event.test } | do $theme

    let result = store query-test $event.suite $event.test
    if ($result | is-empty) {
        error make { msg: $"No test results found for: ($event)" }
    }
    let row = $result | first
    let formatted = format-result $row.result $theme

    if ($row.output | is-not-empty) {
        let output = $row.output | format-output $formatter
        print $"($formatted) ($suite) ($test)\n($output)"
    } else {
        print $"($formatted) ($suite) ($test)"
    }
}

def format-result [result: string, theme: closure]: nothing -> string {
    match $result {
        "PASS" => ({ type: "pass", text: $result } | do $theme)
        "SKIP" => ({ type: "skip", text: $result } | do $theme)
        "FAIL" => ({ type: "fail", text: $result } | do $theme)
        _ => $result
    }
}

def format-output [formatter: closure]: table<stream: string, items: any> -> string {
    let output = $in
    let formatted = $output | do $formatter
    if ($formatted | describe) == "string" {
        $formatted | indent
    } else {
        $formatted
    }
}

def indent []: string -> string {
    "  " + ($in | str replace --all "\n" "\n  ")
}
