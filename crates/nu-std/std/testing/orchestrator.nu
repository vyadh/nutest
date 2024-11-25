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
export def run-suites [reporter: record, threads: int]: list<record> -> nothing {
    "\nrun-suites" | save -a $"z.test"
    $in | par-each { |suite|
        $"\n ($suite) null run-suites" | save -a $"z.test"
        run-suite $reporter $suite.name $suite.path $suite.tests
    }
}

# TODO one failure seems to cause tests to fail

def run-suite [reporter: record, name: string, path: string, tests: table<name: string, type: string>] {
    let plan_data = create-suite-plan-data $tests
    $"\n  ($name) run-suite: ($plan_data)" | save -a $"z.test"

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
    #print $'($plan_data)'
    #print $"($result)"


    if $result.exit_code == 0 {
        $"\n   ($name) null run-suite/stdout:\n====----($result.stdout)----====" | save -a $"z.test"
        $result.stdout
            | lines
            | each { $in | from nuon | process-event $reporter }
    } else {
        $"\n   ($name) null run-suite/stdout: [error]" | save -a $"z.test"
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
    let template = { suite: $event.suite, test: $event.test }
    $"\n   ($event.suite) ($event.test) process-event: ($event.payload)" | save -a $"z.test"

    match $event {
        { type: "result" } => {
            do $reporter.fire-result ($template | merge { result: $event.payload.status })
        }
        { type: "output" } => {
            # TODO concat and fire
            $event.payload.lines | each { |line|
                do $reporter.fire-output ($template | merge { type: output, line: $line })
            }
        }
        { type: "error" } => {
            # TODO concat and fire
            $event.payload.lines | each { |line|
                do $reporter.fire-output ($template | merge { type: error, line: $line })
            }
        }
    }
}
