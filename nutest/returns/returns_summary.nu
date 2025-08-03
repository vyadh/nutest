# Collects summary of results to return

use ../store.nu

export def create []: nothing -> record {
    {
        name: "returns summary"
        results: { query-summary }
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

def count [key: string]: record -> int {
    $in
        | get --optional $key
        | default []
        | length
}
