# A reporter that collects results into a table

use store.nu
use theme.nu

export def create []: nothing -> record {
    {
        start: { store create }
        complete: { store delete }
        success: { store success }
        results: { query-summary }
        has-return-value: true
        fire-start: { |row| }
        fire-finish: { |row| }
        fire-result: { |row| store insert-result $row }
        fire-output: { |row| } # Not required
    }
}

def query-summary []: nothing -> record<total: int, passed: int, failed: int, skipped: int> {
    let results = store query
    let by_result = $results | group-by result

    {
        total: ($results | length)
        passed: ($by_result | count "PASS")
        failed: ($by_result | count "FAIL")
        skipped: ($by_result | count "SKIP")
    }
}

def count [key: string]: list -> int {
    $in
        | get --ignore-errors $key
        | default []
        | length
}
