use std/assert
use db.nu

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
export def run-suites [reporter: record]: list -> nothing {
    $in | par-each { |suite|
        run-suite $reporter $suite.name $suite.path $suite.tests
    }
}

# TODO one failure seems to cause tests to fail

def run-suite [reporter: record, name: string, path: string, tests: table<name: string, type: string>] {
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
    #print $"($result)"

    if $result.exit_code == 0 {
        $result.stdout
            | lines
            | each { $in | from nuon | process-event $reporter }
    } else {
        # This is only triggered on a suite-level failure so not caught by the embedded runner
        # This replicates this suite-level failure down to each test
        $tests | each { |test|
            let template = { timestamp: (date now | format date "%+"), suite: $name, test: $test.name }
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

    let template = {
        timestamp: ($event.timestamp | into datetime)
        suite: $event.suite
        test: $event.test
    }

    try {
        match $event {
            { type: "result" } => {
                do $reporter.fire-result ($template | merge { result: $event.payload.status })
            }
            { type: "output" } => {
                $event.payload.lines | each { |line|
                    do $reporter.fire-output ($template | merge { type: output, line: $line })
                }
            }
            { type: "error" } => {
                $event.payload.lines | each { |line|
                    do $reporter.fire-output ($template | merge { type: error, line: $line })
                }
            }
        }
    } catch { |error|
        # Catches errors in the reporter, though we can't seem to print nicely
        print -e $error.debug
        exit 1
    }
}
