# Collects results into a table to display

use ../store.nu
use ../theme.nu
use ../formatter.nu

export def create []: nothing -> record<name: string, run-start: closure, run-complete: closure, test-start: closure, test-complete: closure> {
    let theme = theme standard
    let error_format = "compact"
    let formatter = formatter pretty $theme $error_format

    {
        name: "display table"
        run-start: { || ignore }
        run-complete: { || print (query-results $theme $formatter) }
        test-start: { |row| ignore }
        test-complete: { |row| ignore }

        # Easier testing
        results: { query-results $theme $formatter }
    }
}

def query-results [
    theme: closure
    formatter: closure
]: nothing -> table<suite: string, test: string, result: string, output: string> {

    store query | each { |row|
        {
            suite: ({ type: "suite", text: $row.suite } | do $theme)
            test: ({ type: "test", text: $row.test } | do $theme)
            result: (format-result $row.result $theme)
            output: ($row.output | do $formatter)
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
