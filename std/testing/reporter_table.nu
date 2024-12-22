# A reporter that collects results into a table

use store.nu

export def create [theme: closure]: nothing -> record {
    {
        start: { store create }
        complete: { store delete }
        success: { store success }
        results: { query-results $theme }
        has-return-value: true
        fire-start: { |row| }
        fire-finish: { |row| }
        fire-result: { |row| store insert-result $row }
        fire-output: { |row| store insert-output $row }
    }
}

def query-results [theme: closure]: nothing -> table<suite: string, test: string, result: string, output: string> {
    store query | each { |row|
        {
            suite: ({ type: "suite", text: $row.suite } | do $theme)
            test: ({ type: "test", text: $row.test } | do $theme)
            result: (format-result $row.result $theme)
            output: ($row.output | render $theme)
        }
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

def render [theme: closure]: table<stream: string, items: list<any>> -> string {
    $in
        #| each { |row| $row.items } # Skip theme for now
        #| str join "\n" # Render as lines
}
