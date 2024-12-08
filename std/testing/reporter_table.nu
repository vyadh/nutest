# A reporter that collects results into a table

use store.nu

export def create [theme: closure]: nothing -> record {
    {
        start: { store create }
        complete: { store delete }
        success: { store success }
        results: { query-results $theme }
        fire-result: { |row| insert-result $row }
        fire-output: { |row| insert-output $row }
    }
}

def query-results [theme: closure]: nothing -> table<suite: string, test: string, result: string, output: string, error: string> {
    let res = store query $theme | each { |row|
        {
            suite: $row.suite
            test: $row.test
            result: (format-result $row.result $theme)
            output: $row.output
        }
    }
    $res
}

def format-result [result: string, theme: closure]: nothing -> string {
    match $result {
        "PASS" => ({ type: "pass", text: $result } | do $theme)
        "SKIP" => ({ type: "skip", text: $result } | do $theme)
        "FAIL" => ({ type: "fail", text: $result } | do $theme)
        _ => $result
    }
}

def insert-result [row: record<suite: string, test: string, result: string>] {
    store insert-result $row
}

def insert-output [row: record<suite: string, test: string, type: string, lines: list<string>>] {
    store insert-output $row
}
