
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
            | query db $"
                SELECT suite, test, result
                FROM nu_tests
                ORDER BY suite, test
            "
            | each { |row|
                {
                    suite: $row.suite
                    test: $row.test
                    result: $row.result
                    output: (query-output $row.suite $row.test "output")
                    error: (query-output $row.suite $row.test "error")
                }
            }
    )
}

# TODO use subquery instead
def query-output [suite: string, test: string, type: string]: nothing -> string {
    (
        stor open
            | query db $"
                SELECT line
                FROM nu_test_output
                WHERE suite = :suite AND test = :test AND type = :type
            " --params { suite: $suite, test: $test, type: $type }
            | get line
            | str join "\n"
    )
}
