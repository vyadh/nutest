# A reporter that collects results into a table

use store.nu

export def create [theme: closure, formatter: closure]: nothing -> record {
    {
        start: { start-suite }
        complete: { complete-suite }
        success: { success }
        results: { [] }
        has-return-value: false
        fire-start: { |row| start-test $row }
        fire-finish: { |row| $row | complete-test $theme $formatter }
        fire-result: { |row| fire-result $row }
        fire-output: { |row| fire-output $row }
    }
}

def start-suite []: nothing -> nothing {
    print "Running tests..."
    store create
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

    store delete
}

def count [key: string]: list -> int {
    $in
        | get --ignore-errors $key
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
    let row = $result | first
    let formatted = format-result $row.result $theme

    if ($row.output | is-not-empty) {
        let output = ($row.output | do $formatter $theme) | indent
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

def indent []: string -> string {
    "  " + ($in | str replace --all "\n" "\n  ")
}

def fire-result [row: record<suite: string, test: string, result: string>] {
    store insert-result $row
}

def fire-output [row: record<suite: string, test: string, data: string>] {
    store insert-output $row
}

def success [] {
    store success
}
