use ../store.nu
use ../formatter.nu

export def create []: nothing -> record {
    let formatter = formatter unformatted

    {
        name: "returns table"
        results: { query-results $formatter }
    }
}

def query-results [
    formatter: closure
]: nothing -> table<suite: string, test: string, result: string, output: string> {

    store query | each { |row|
        {
            suite: $row.suite
            test: $row.test
            result: $row.result
            output: ($row.output | do $formatter)
        }
    }
}
