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
export def run-suites [
    reporter: record,
    strategy: record
]: list<record<name: string, path: string, tests: table>> -> nothing {

    $in | par-each --threads $strategy.threads { |suite|
        run-suite $reporter $strategy $suite.name $suite.path $suite.tests
    }
}

def run-suite [
    reporter: record
    strategy: record
    suite: string
    path: string
    tests: table<name: string, type: string>
] {
    let plan_data = create-suite-plan-data $tests

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use (runner-module) *
                source ($path)
                nutest-299792458-execute-suite ($strategy | to nuon) ($suite) ($plan_data)
            "
    ) | complete

    # Useful for understanding plan
    #print $'($plan_data)'

    if $result.exit_code == 0 {
        for line in ($result.stdout | lines) {
            let event = $line | from nuon

            # Useful for understanding event stream
            #print ($event | table --expand)

            $event | process-event $reporter
        }
    } else {
        # This is only triggered on a suite-level failure so not caught by the embedded runner
        # This replicates this suite-level failure down to each test
        for test in $tests {
            let template = { timestamp: (date now | format date "%+"), suite: $suite, test: $test.name }
            $template | merge { type: "start", payload: null } | process-event $reporter
            $template | merge { type: "result", payload: { status: "FAIL" } } | process-event $reporter
            $template | merge (as-error-output $result.stderr) | process-event $reporter
            $template | merge { type: "finish", payload: null } | process-event $reporter
        }
    }
}

def runner-module []: nothing -> string {
    let in_std = scope modules | where file == "std/testing/mod.nu" | is-not-empty
    if $in_std {
        "std/testing/runner.nu"
    } else {
        # Can't just use `path self` directly for both cases, as it's currently wrong for virtual/std files
        const runner_nu = path self "runner.nu"
        $runner_nu
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
def as-error-output [error: string]: record -> record {
    {
        type: "output"
        payload: ({ stream: "error", items: [$error] } | to nuon | encode base64)
    }
}

def process-event [reporter: record] {
    let event = $in
    let template = { suite: $event.suite, test: $event.test }

    match $event {
        { type: "start" } => {
            do $reporter.fire-start $template
        }
        { type: "finish" } => {
            do $reporter.fire-finish $template
        }
        { type: "result" } => {
            let message = $template | merge { result: $event.payload.status }
            do $reporter.fire-result $message
        }
        { type: "output" } => {
            let decoded = $event.payload | decode base64 | decode
            let message = $template | merge { data: $decoded }
            do $reporter.fire-output $message
        }
    }
}
