use std/assert

module db.nu
use db

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
export def run-suites [suites: list]: nothing -> table<suite: string, test: string, result: string, output: string, error: string> {
    $suites | par-each { |suite|
        run-suite $suite.name $suite.path $suite.tests
    }
    db query
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
        # This is only triggered on a suite-level failure so not caught by the embedded runner
        # This replicates this suite-level failure down to each test
        $tests | each { |test|
            let template = { timestamp: (date now | format date "%+"), suite: $name, test: $test.name }
            $template | merge { type: "result", payload: { status: "FAIL" } } | process-event
            $template | merge { type: "error", payload: { lines: [$result.stderr] } } | process-event
        }
    }
}

export def create-suite-plan-data [tests: table<name: string, type: string>]: nothing -> string {
    let plan_data = $tests
            | each { |test| create-test-plan-data $test }
            | str join ", "

    $"[ ($plan_data) ]"
}

def create-test-plan-data [test: record<name: string, type: string>]: nothing -> string {
    $'{ name: "($test.name)", type: "($test.type)", execute: { ($test.name) } }'
}

def process-event [] {
    let event = $in
    let template = { suite: $event.suite, test: $event.test }

    match $event {
        { type: "result" } => {
            db insert-result ($template | merge { result: $event.payload.status })
        }
        { type: "output" } => {
            $event.payload.lines | each { |line|
                db insert-output ($template | merge { type: output, line: $line })
            }
        }
        { type: "error" } => {
            $event.payload.lines | each { |line|
                db insert-output ($template | merge { type: error, line: $line })
            }
        }
    }
}
