use std/assert

def main [] {
    create
    try {

        # 1 suite
        # 10 tests
        # 1 result
        # 5 outputs + 5 errors
        # 1 query

        let tests = 0..500
        let outputs = 1..50

        let data = $tests | each { |test|
            {
                suite: "s"
                test: $"test-($test)"
                result: "PASS"
                output: ($outputs | each { |line| $"out-($line)" } | str join "\n")
                error: ($outputs  | each { |line| $"err-($line)" } | str join "\n")
            }
        }

        $data | par-each { |test|
            let template = $test | reject result output error

            let result = $template | merge { result: "PASS" }
            insert-result $result

            $test.output | lines | each { |line|
                let out = $template | merge { type: "output", line: $line }
                insert-output $out
            }

            $test.error | lines | each { |line|
                let out = $template | merge { type: "error", line: $line }
                insert-output $out
            }

            let this = $data | where suite == $test.suite and test == $test.test
            let that = query | where suite == $test.suite and test == $test.test

            if ($this != $that) {
                print ($this)
                print ($that)
            }
            assert equal ($this) ($that)
        }

        #print ($data)
        #(query)

    } catch { |e|
        delete
        $e.raw
    }
}

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
    #stor open | query db $"
    #    --BEGIN TRANSACTION;
    #    INSERT INTO nu_tests \(suite, test, result\)
    #      VALUES \('($row.suite)', '($row.test)', '($row.result)'\);
    #    --COMMIT TRANSACTION;
    #"
    # --params $row
    retry-on-lock "nu_tests" {
        $row | stor insert --table-name nu_tests
    }
}

export def insert-output [ row: record<suite: string, test: string, type: string, line: string> ] {
    #stor open | query db $"
    #    BEGIN TRANSACTION;
    #    INSERT INTO nu_test_output \(suite, test, type, line\)
    #      VALUES \('($row.suite)', '($row.test)', '($row.type)', '($row.line)'\);
    #    COMMIT TRANSACTION;
    #"
    #stor open | query db "
    #    BEGIN TRANSACTION;
    #    INSERT INTO nu_test_output (suite, test, type, line)
    #      VALUES (:suite, :test, :type, :line);
    #    END TRANSACTION
    #" --params $row

    retry-on-lock "nu_test_output" {
        $row | stor insert --table-name nu_test_output
    }
}

# Parallel execution of tests causes contention on the SQLite database
# which leads to failed inserts or missing data.
def retry-on-lock [table: string, operation: closure] {
    # We should eventually give up as an error flagging a bug is better than an infinite loop
    # Through stress testing, this number should be good for 500 tests with 50 lines of output/error
    let max_attempts = 20
    mut attempt = $max_attempts
    while $attempt > 0 {
        #print $"Attempt: ($attempts)"
        $attempt -= 1
        try {
            do $operation
            if $attempt < ($max_attempts - 1) {
                #print "success!"
            }
            break
        } catch { |e|
            let reason = ($e.json | from json).labels?.0?.text?
            if $reason == $"database table is locked: ($table)" {
                #print "retrying"
                continue
            }
        }
    }
    if $attempt == 0 {
        print $"Given up: ($attempt)"
    }
}


export def query []: nothing -> table<suite: string, test: string, result: string, output: string, error: string> {
    (
        stor open
            | query db "
                --BEGIN TRANSACTION;

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

                ORDER BY r.suite, r.test;

                --COMMIT TRANSACTION
            "
    )
}
