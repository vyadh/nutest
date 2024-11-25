use std/assert
use store.nu

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
export def run-suites [reporter: record, threads: int]: list<record> -> nothing {
    $in | par-each --threads $threads { |suite|
        run-suite $reporter $threads $suite.name $suite.path $suite.tests
    }
}

# TODO one failure seems to cause (all?) tests to fail

def run-suite [reporter: record, threads: int, suite: string, path: string, tests: table<name: string, type: string>] {
    let plan_data = create-suite-plan-data $tests

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                source std/testing/runner.nu
                source ($path)
                plan-execute-suite-emit ($suite) ($threads) ($plan_data)
            "
    ) | complete

    # Useful for understanding event stream
    #print $'($plan_data)'
    #print $"($result)"

    if $result.exit_code == 0 {
        $result.stdout
            | lines
            | each { $in | from nuon | process-event $reporter }
    } else {
        # This is only triggered on a suite-level failure so not caught by the embedded runner
        # This replicates this suite-level failure down to each test
        $tests | each { |test|
            let template = { timestamp: (date now | format date "%+"), suite: $suite, test: $test.name }
            $template | merge { type: "result", payload: { status: "FAIL" } } | process-event $reporter
            $template | merge { type: "error", payload: { lines: [$result.stderr] } } | process-event $reporter
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

def process-event [reporter: record] {
    let event = $in
    let template = { suite: $event.suite, test: $event.test }

    match $event {
        { type: "result" } => {
            let message = $template | merge { result: $event.payload.status }
            do $reporter.fire-result $message
        }
        { type: "output" } => {
            let message = $template | merge { type: output, lines: $event.payload.lines }
            do $reporter.fire-output $message
        }
        { type: "error" } => {
            let message = $template | merge { type: error, lines: $event.payload.lines }
            do $reporter.fire-output $message
        }
    }
}
