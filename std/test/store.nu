
export def create [] {
    stor create --table-name nu_test_results --columns {
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

# We close the store so tests of this do not open the store multiple times
export def delete [] {
    stor delete --table-name nu_test_results
    stor delete --table-name nu_test_output
}

export def insert-result [ row: record<suite: string, test: string, result: string> ] {
    retry-on-lock "nu_test_results" {
        $row | stor insert --table-name nu_test_results
    }
}

export def insert-output [ row: record<suite: string, test: string, type: string, lines: list<string>> ] {
    retry-on-lock "nu_test_output" {
        $row
            | reject lines
            | merge { line: ($row.lines | str join "\n") }
            | stor insert --table-name nu_test_output
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
            break
        } catch { |e|
            let reason = ($e.json | from json).labels?.0?.text?
            if $reason == $"database table is locked: ($table)" {
                # Retry
                continue
            } else {
                $e.raw # Rethrow anything else
            }
        }
    }
    if $attempt == 0 {
        error make { msg: $"Failed to insert into ($table) after ($max_attempts) attempts" }
    }
}

export def success []: nothing -> bool {
    let has_failures = stor open | query db "
        SELECT EXISTS (
            SELECT 1
            FROM nu_test_results
            WHERE result = 'FAIL'
        ) AS failures
    " | get failures.0 | into bool

    not $has_failures
}

export def query [color_scheme: closure]: nothing -> table<suite: string, test: string, result: string, output: string, error: string> {
    # SQL doesn't have backslash escapes so we use `char(10)`, being newline (\n)
    (
        stor open
            | query db "
                WITH
                    -- Combine the output and error lines into a single column with errors highlighted
                    stream AS (
                        SELECT
                            suite,
                            test,
                            GROUP_CONCAT(
                                CASE
                                    WHEN type = 'error' THEN :error_prefix || line || :error_suffix
                                    ELSE line
                                END,
                                char(10)
                            ) AS output
                        FROM nu_test_output
                        GROUP BY suite, test
                    ),

                    -- A test can pass and then fail due to after-all post-processing
                    -- Below extracts only the last result reported based on insertion order
                    results AS (
                        SELECT
                            suite,
                            test,
                            result,
                            ROW_NUMBER() OVER (PARTITION BY suite, test ORDER BY rowid DESC) AS row
                        FROM nu_test_results
                    )

                SELECT
                    r.suite,
                    r.test,
                    r.result,
                    COALESCE(s.output, '') AS output

                FROM results AS r

                LEFT JOIN stream AS s
                ON r.suite = s.suite AND r.test = s.test

                -- The last result for each test given tests can pass then fail
                WHERE r.row = 1

                ORDER BY r.suite, r.test
            " --params {
                error_prefix: ({ prefix: "stderr" } | do $color_scheme)
                error_suffix: ({ suffix: "stderr" } | do $color_scheme)
            }
    )
}
