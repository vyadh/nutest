
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
                WITH
                    aggregated_output AS (
                        SELECT
                            suite,
                            test,
                            GROUP_CONCAT(line, '\n') AS output
                        FROM nu_test_output
                        WHERE type = 'output'
                        GROUP BY suite, test
                    ),
                    aggregated_error AS (
                        SELECT
                            suite,
                            test,
                            GROUP_CONCAT(line, '\n') AS error
                        FROM nu_test_output
                        WHERE type = 'error'
                        GROUP BY suite, test
                    )

                SELECT
                    r.suite,
                    r.test,
                    r.result,
                    COALESCE(o.output, '') AS output,
                    COALESCE(e.error, '') AS error

                FROM nu_tests AS r

                LEFT JOIN aggregated_output AS o
                ON r.suite = o.suite AND r.test = o.test

                LEFT JOIN aggregated_error AS e
                ON r.suite = e.suite AND r.test = e.test

                ORDER BY r.suite, r.test
            "
    )
}
