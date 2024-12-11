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
}

def complete-suite []: nothing -> nothing {
    print "Test run completed"
}

def start-test [row: record]: nothing -> nothing {
    print $"Running test: ($row.suite) ($row.test)..."
}

def complete-test [row: record]: nothing -> nothing {
    print $"...completed test: ($row.suite) ($row.test)"
}

def success [] {
    # Not relevant for terminal mode
    true
}

def fire-result [theme: closure, row: record<suite: string, test: string, result: string>] {
    let formatted = (format-result $row.result $theme)
    let suite = { type: "suite", text: $row.suite } | do $theme
    let test = { type: "test", text: $row.test } | do $theme
    print $"($formatted) ($suite) ($test)"
}

def fire-output [theme: closure, row: record<suite: string, test: string, type: string, lines: list<string>>] {
}

def format-result [result: string, theme: closure]: nothing -> string {
    match $result {
        "PASS" => ({ type: "pass", text: $result } | do $theme)
        "SKIP" => ({ type: "skip", text: $result } | do $theme)
        "FAIL" => ({ type: "fail", text: $result } | do $theme)
        _ => $result
    }
}
