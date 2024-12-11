# A reporter that collects results into a table

use store.nu

export def create [theme: closure]: nothing -> record {
    {
        start: { start-suite }
        complete: { complete-suite }
        success: { success }
        results: { [] }
        fire-start: { |row| start-test $row }
        fire-finish: { |row| complete-test $row }
        fire-result: { |row| fire-result $theme $row }
        fire-output: { |row| fire-output $theme $row }
    }
}

def start-suite []: nothing -> nothing {
    print "Running tests..."
    store create
}

def complete-suite []: nothing -> nothing {
    let results = store query (theme none)
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
    print $"Running test: ($row.suite) ($row.test)..."
}

def complete-test [row: record]: nothing -> nothing {
    print $"...completed test: ($row.suite) ($row.test)"
}

def success [] {
    store success
}

def fire-result [theme: closure, row: record<suite: string, test: string, result: string>] {
    store insert-result $row

    let formatted = (format-result $row.result $theme)
    let suite = { type: "suite", text: $row.suite } | do $theme
    let test = { type: "test", text: $row.test } | do $theme
    # TODO limit to suite and test in SQL query rather than get everything every time
    let lines = store query $theme
        | where $row.result == "FAIL"
        | where $row.suite == $it.suite and $row.test == $it.test
        | each { |row| $row.output }
        | str join "\n"
        | str replace --all "\\n" "\n"
        | str trim
        | str replace --all "\n" "\n  "
        # TODO Would be better to normalise newlines above on the way in rather than here

    if ($lines | is-not-empty) {
        print $"($formatted) ($suite) ($test)\n  ($lines)"
    } else {
        print $"($formatted) ($suite) ($test)"
    }
}

def fire-output [theme: closure, row: record<suite: string, test: string, type: string, lines: list<string>>] {
    store insert-output $row
}

def format-result [result: string, theme: closure]: nothing -> string {
    match $result {
        "PASS" => ({ type: "pass", text: $result } | do $theme)
        "SKIP" => ({ type: "skip", text: $result } | do $theme)
        "FAIL" => ({ type: "fail", text: $result } | do $theme)
        _ => $result
    }
}
