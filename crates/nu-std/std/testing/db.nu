
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
    # TODO inconsistent naming
    stor delete --table-name nu_tests
    stor delete --table-name nu_test_output
}

export def insert-result [ row: record<suite: string, test: string, result: string> ] {
    retry-on-lock "nu_tests" {
        $row | stor insert --table-name nu_tests
    }
}

export def insert-output [ row: record<suite: string, test: string, type: string, line: string> ] {
    retry-on-lock "nu_test_output" {
        $row | stor insert --table-name nu_test_output
    }
}

# Parallel execution of tests causes contention on the SQLite database,
# which leads to failed inserts or missing data.
def retry-on-lock [table: string, operation: closure] {
    # We should eventually give up as an error flagging a bug is better than an infinite loop
    # Through stress testing, this number should be good for 500 tests with 50 lines of output/error
    let max_attempts = 20
    mut attempt = $max_attempts
    while $attempt > 0 {
        $attempt -= 1
        try {
            do $operation
            if $attempt < ($max_attempts - 1) {
            }
            break
        } catch { |e|
            let reason = ($e.json | from json).labels?.0?.text?
            if $reason == $"database table is locked: ($table)" {
                continue
            }
        }
    }
    if $attempt == 0 {
        error make { msg: $"Failed to insert into ($table) after ($max_attempts) attempts" }
    }
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
