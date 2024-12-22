
# We use `query db` here rather than `stor create` as we need full SQLite features
export def create [] {
    let db = stor open

    $db | query db "
        CREATE TABLE nu_test_results (
            suite TEXT NOT NULL,
            test TEXT NOT NULL,
            result TEXT,
            PRIMARY KEY (suite, test)
        )
    "

    $db | query db "
        CREATE TABLE nu_test_output (
            suite TEXT NOT NULL,
            test TEXT NOT NULL,
            type TEXT NOT NULL,
            line TEST
        )
    "

    $db | query db "
        CREATE INDEX idx_suite_test ON nu_test_output (suite, test)
    "
}

# We close the store so tests of this do not open the store multiple times
export def delete [] {
    stor delete --table-name nu_test_results
    stor delete --table-name nu_test_output
}

export def insert-result [ row: record<suite: string, test: string, result: string> ] {
    retry-on-lock "nu_test_results" {
        stor open | query db "
            INSERT INTO nu_test_results (suite, test, result)
            VALUES (:suite, :test, :result)
            ON CONFLICT(suite, test)
            DO UPDATE SET result = excluded.result
        " --params {
            suite: $row.suite
            test: $row.test
            result: $row.result
        }
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
                # Retry after a random sleep to avoid contention
                sleep (random int ..25 | into duration --unit ms)
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

export def query []: nothing -> table<suite: string, test: string, result: string, output: string> {
    let db = stor open
    $db | query db "
        SELECT suite, test, result
        FROM nu_test_results
        ORDER BY suite, test
    " | insert output { |row|
        $db | query db (query-output) --params {
            suite: $row.suite
            test: $row.test
        } | get output | default [] | str join "\n"
    }
}

export def query-test [
    suite: string
    test: string
]: nothing -> table<suite: string, test: string, result: string, output: string> {

    let db = stor open
    $db | query db "
        SELECT suite, test, result
        FROM nu_test_results
        WHERE suite = :suite AND test = :test
    " --params {
        suite: $suite
        test: $test
    } | insert output { |row|
        $db | query db (query-output) --params {
            suite: $suite
            test: $test
        } | get output | default [] | str join "\n"
    }
}

def query-output []: nothing -> string {
    "
        -- Combine the output and error lines into a single column with errors highlighted
        SELECT
            suite,
            test,
            COALESCE(GROUP_CONCAT(line, char(10)), '') AS output
        FROM nu_test_output
        WHERE suite = :suite AND test = :test
    "
}
