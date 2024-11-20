use std/assert

# This script generates the test suite data and embeds a runner into a nushell sub-process to execute.

# INPUT DATA STRUCTURES
#
# test:
# {
#     name: string
#     type: string
# }
#
# suite:
# {
#     name: string
#     path: string
#     tests: list<test>
# }
#
# OUTPUT DATA STRUCTURES
#
# test-result:
# {
#     suite: string
#     test: string
#     result: bool
#     output: string
#     error: string
# }
#
# suite-result:
# {
#     name: string
#     results: list<test-result>
# }

#suites: table<name: string, path: string, tests: table<name: string, type: string>>
export def run-suites [suites: list] -> table<name: string, results: table<name: string, result: bool, output: string, error: string> {
    db-create

    $suites | par-each { |suite|
        run-suite $suite.name $suite.path $suite.tests
    }

    let results = db-query

    db-delete

    $results
}

def run-suite [name: string, path: string, tests: table<name: string, type: string>] {
    let plan_data = create-suite-plan-data $tests

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                source std/testing/runner.nu
                source ($path)
                plan-execute-suite-emit ($name) ($plan_data)
            "
    ) | complete # TODO need a streaming version

    # Useful for understanding event stream
    #print $result

    if $result.exit_code == 0 {
        $result.stdout
            | lines
            | each { $in | from nuon | process-event }
    } else {
        # This is only triggered on a suite-level failure not caught by the embedded runner
        # Replicate this suite-level failure for every test
        $tests | each { |test|
            {
                timestamp: (date now | format date "%+")
                suite: $name
                test: $test.name
                type: "result"
                payload: { success: false }
            } | process-event
            {
                timestamp: (date now | format date "%+")
                suite: $name
                test: $test.name
                type: "error"
                payload: { lines: [$result.stderr] }
            } | process-event
        }
    }
}

export def create-suite-plan-data [tests: table<name: string, type: string>] -> string {
    let plan_data = $tests
            | each { |test| create-test-plan-data $test }
            | str join ", "

    $"[ ($plan_data) ]"
}

def create-test-plan-data [test: record<name: string, type: string>] -> string {
    $'{ name: "($test.name)", type: "($test.type)", execute: { ($test.name) } }'
}

def process-event [] {
    let event = $in
    let template = { suite: $event.suite, test: $event.test }

    match $event {
        { type: "result" } => {
            let row = $template | merge { success: $event.payload.success }
            $row | stor insert --table-name nu_tests
        }
        { type: "output" } => {
            $event.payload.lines | each { |line|
                let row = $template | merge { type: output, line: $line }
                $row | stor insert --table-name nu_test_output
            }
        }
        { type: "error" } => {
            $event.payload.lines | each { |line|
                let row = $template | merge { type: error, line: $line }
                $row | stor insert --table-name nu_test_output
            }
        }
    }
}

def db-create [] {
    stor create --table-name nu_tests --columns {
        suite: str
        test: str
        success: bool
    }
    stor create --table-name nu_test_output --columns {
        suite: str
        test: str
        type: str
        line: str
    }
}

# We close the db so tests of this do not open the db multiple times
def db-delete [] {
    stor delete --table-name nu_tests
    stor delete --table-name nu_test_output
}

def db-query [] -> record {
    (
        stor open
            | query db $"
                SELECT suite, test, success
                FROM nu_tests
                ORDER BY suite, test
            "
            | each { |row|
                {
                    suite: $row.suite
                    test: $row.test
                    success: (if $row.success == 1 { true } else { false })
                    output: (db-query-output $row.suite $row.test "output")
                    error: (db-query-output $row.suite $row.test "error")
                }
            }
    )
}

# TODO use subquery instead
def db-query-output [suite: string, test: string, type: string] -> string {
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
