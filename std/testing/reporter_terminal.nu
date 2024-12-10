# A reporter that collects results into a table

use store.nu

export def create [theme: closure]: nothing -> record {
    {
        start: { start }
        complete: { complete }
        success: { success }
        results: { [] }
        fire-result: { |row| fire-result $theme $row }
        fire-output: { |row| fire-output $theme $row }
    }
}

def start []: nothing -> nothing {
    print "Running tests..."
}

def complete []: nothing -> nothing {
    print "Test run completed"
}

def success [] {
    # Not relevant for terminal mode
    true
}

def fire-result [theme: closure, row: record<suite: string, test: string, result: string>] {
    let formatted = (format-result $row.result $theme)
    # TODO use theme for suite and test colours
    print $"($formatted) (ansi light_blue)($row.suite)(ansi reset) ($row.test)"
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
