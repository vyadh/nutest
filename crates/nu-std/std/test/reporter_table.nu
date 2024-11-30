# A reporter that collects results into a table

use store.nu

export def create [color_scheme: closure]: nothing -> record {
    {
        start: { store create }
        complete: { store delete }
        success: { store success }
        results: { query-results $color_scheme }
        fire-result: { |row| insert-result $row }
        fire-output: { |row| insert-output $row }
    }
}

def query-results [color_scheme: closure]: nothing -> table<suite: string, test: string, result: string, output: string, error: string> {
    let res = store query $color_scheme | each { |row|
        {
            suite: $row.suite
            test: $row.test
            result: (format-result $row.result $color_scheme)
            output: $row.output
        }
    }
    $res
}

def format-result [result: string, color_scheme: closure]: nothing -> string {
    match $result {
        "PASS" => ({ type: "pass", text: $result } | do $color_scheme)
        "SKIP" => ({ type: "skip", text: $result } | do $color_scheme)
        "FAIL" => ({ type: "fail", text: $result } | do $color_scheme)
        _ => $result
    }
}

def insert-result [row: record<suite: string, test: string, result: string>] {
    store insert-result $row
}

def insert-output [row: record<suite: string, test: string, type: string, lines: list<string>>] {
    store insert-output $row
}
