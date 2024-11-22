
export def create [] {
    stor create --table-name nu_tests --columns {
        suite: str
        test: str
        result: str
    }
    stor create --table-name nu_test_output --columns {
        suite: str
        test: str
        type: str
        line: str
    }
}

# We close the db so tests of this do not open the db multiple times
export def delete [] {
    stor delete --table-name nu_tests
    stor delete --table-name nu_test_output
}

export def insert-result [ row: record<suite: string, test: string, result: string> ] {
    $row | stor insert --table-name nu_tests
}

export def insert-output [ row: record<suite: string, test: string, type: string, line: string> ] {
    $row | stor insert --table-name nu_test_output
}

export def query []: nothing -> table<suite: string, test: string, result: string, output: string, error: string> {
    (
        stor open
            | query db "
                SELECT
                    r.suite,
                    r.test,
                    r.result,
                    GROUP_CONCAT(o.line, '\n') AS output,
                    GROUP_CONCAT(e.line, '\n') AS error

                FROM nu_tests AS r

                LEFT JOIN nu_test_output AS o
                ON r.suite = o.suite AND r.test = o.test AND o.type = 'output'

                LEFT JOIN nu_test_output AS e
                ON r.suite = e.suite AND r.test = e.test AND e.type = 'error'

                GROUP BY r.suite, r.test
                ORDER BY r.suite, r.test
            "
            | each { |row|
                {
                    suite: $row.suite
                    test: $row.test
                    result: $row.result
                    output: ($row.output | default "")
                    error: ($row.error | default "")
                }
            }
    )
}
