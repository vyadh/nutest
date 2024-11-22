# A reporter that collects results into a table

use db.nu

export def create []: nothing -> record {
    {
        start: { db create }
        complete: { db delete }
        results: { query-results }
        fire-result: { |row| insert-result $row }
        fire-output: { |row| insert-output $row }
    }
}

def query-results []: nothing -> table<suite: string, test: string, result: string, output: string, error: string> {
    db query | each { |row|
        {
            suite: $row.suite
            test: $row.test
            result: $row.result
            output: ($row.output | default "")
            error: ($row.error | default "")
        }
    }
}

def insert-result [row: record<suite: string, test: string, result: string>] {
    db insert-result $row
}

def insert-output [row: record<suite: string, test: string, type: string, line: string>] {
    db insert-output $row
}
