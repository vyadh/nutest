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
export def run-suites [
    event_processor: record<run-start: closure, run-complete: closure, test-start: closure, test-complete: closure>
    strategy: record
]: list<record<name: string, path: string, tests: table>> -> nothing {

    $in | par-each --threads $strategy.threads { |suite|
        run-suite $event_processor $strategy $suite.name $suite.path $suite.tests
    }
}

def run-suite [
    event_processor: record<run-start: closure, run-complete: closure, test-start: closure, test-complete: closure>
    strategy: record
    suite: string
    path: string
    tests: table<name: string, type: string>
] {
    let plan_data = create-suite-plan-data $tests

    # Run with forced colour to get colourised rendered error output
    let result = with-env { FORCE_COLOR: true } {
        const runner_module = path self "runner.nu"
        (^$nu.current-exe
            --commands $"
                use ($runner_module) *
                source ($path)
                nutest-299792458-execute-suite ($strategy | to nuon) ($suite) ($plan_data)
        ")
    } | complete

    # Useful for understanding plan
    #print $'($plan_data)'

    if $result.exit_code == 0 {
        for line in ($result.stdout | lines) {
            try {
                let event = $line | from nuon

                # Useful for understanding event stream
                #print ($event | table --expand)

                $event | process-event $event_processor
            } catch { |error|
                if $error.msg == "error when loading nuon text" {
                    # Test printed direct to stdout so runner could not capture output,
                    # which means we cannot associate with a specific test
                    print -e $"Warning: Non-captured output for '($suite)': ($line)"
                } else {
                    $error.raw
                }
            }
        }
    } else {
        # This is only triggered on a suite-level failure so not caught by the embedded runner
        # This replicates this suite-level failure down to each test
        for test in $tests {
            let template = { timestamp: (date now | format date "%+"), suite: $suite, test: $test.name }
            $template | merge { type: "start", payload: null } | process-event $event_processor
            $template | merge { type: "result", payload: "FAIL" } | process-event $event_processor
            $template | merge (as-error-output $result.stderr) | process-event $event_processor
            $template | merge { type: "finish", payload: null } | process-event $event_processor
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

# Need to encode orchestrator errors as the runner would do, and compatible with the store output
def as-error-output [error: string]: nothing -> record {
    {
        type: "output"
        payload: ({ stream: "error", items: [$error] } | to nuon | encode base64)
    }
}

def process-event [
    event_processor: record<run-start: closure, run-complete: closure, test-start: closure, test-complete: closure>
] {
    let event = $in
    let template = { suite: $event.suite, test: $event.test }

    match $event {
        { type: "start" } => {
            do $event_processor.test-start $template
        }
        { type: "finish" } => {
            do $event_processor.test-complete $template
        }
        { type: "result" } => {
            let message = $template | merge { result: $event.payload }
            store insert-result $message
        }
        { type: "output" } => {
            let decoded = $event.payload | decode base64 | decode
            let message = $template | merge { data: $decoded }
            store insert-output $message
        }
    }
}
