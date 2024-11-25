# A reporter that collects results into a table

use db.nu

export def create [color: bool = false]: nothing -> record {
    {
        start: { db create }
        complete: { db delete }
        results: { query-results $color }
        fire-result: { |row| insert-result $row }
        fire-output: { |row| insert-output $row }
    }
}

def query-results [color: bool]: nothing -> table<suite: string, test: string, result: string, output: string, error: string> {
    let rand = random chars --length 8
    let res = db query | each { |row|
        $"\n   ($row.suite) ($row.test) query1 [($rand)]: ($row)" | save -a $"z.test"
        {
            suite: $row.suite
            test: $row.test
            result: (format-result $row.result $color)
            output: $row.output
            error: $row.error
        }
    }
    #db query-out | each { |row|
    #    $"\n   ($row.suite) ($row.test) query2 [($rand)]: ($row)" | save -a $"z.test"
    #}
    $res
}

def format-result [result: string, $color]: nothing -> string {
    if $color {
        match $result {
            "PASS" => $"(ansi green)($result)(ansi reset)"
            "SKIP" => $"(ansi yellow)($result)(ansi reset)"
            "FAIL" => $"(ansi red)($result)(ansi reset)"
            _ => $result
        }
    } else {
        $result
    }
}

def insert-result [row: record<suite: string, test: string, result: string>] {
    db insert-result $row
}

def insert-output [row: record<suite: string, test: string, type: string, line: string>] {
    db insert-output $row
}
