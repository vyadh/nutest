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
export def run-suites [reporter: record, threads: int]: list<record> -> nothing {
    $in | par-each --threads $threads { |suite|
        run-suite $reporter $threads $suite.name $suite.path $suite.tests
    }
}

def run-suite [reporter: record, threads: int, suite: string, path: string, tests: table<name: string, type: string>] {
    let plan_data = create-suite-plan-data $tests

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use (runner-module) *
                source ($path)
                nutest-299792458-execute-suite ($suite) ($threads) ($plan_data)
            "
    ) | complete

    # Useful for understanding event stream
    #print $'($plan_data)'

    if $result.exit_code == 0 {
        for line in ($result.stdout | lines) {
            let event = $line | decode-event
            $event | process-event $reporter
        }
    } else {
        # This is only triggered on a suite-level failure so not caught by the embedded runner
        # This replicates this suite-level failure down to each test
        for test in $tests {
            let template = { timestamp: (date now | format date "%+"), suite: $suite, test: $test.name }
            $template | merge { type: "result", payload: { status: "FAIL" } } | process-event $reporter
            $template | merge { type: "error", payload: { data: [$result.stderr] } } | process-event $reporter
        }
    }
}

def runner-module []: nothing -> string {
    let files = scope modules | where name == "runner" | get file
    if ($files | is-empty) {
        # This is required when nu-test is embedded in the standard library
        return "std/testing/runner.nu"
    } else {
        # This is required when nu-test is run as a separate module
        $files | first
    }
}

def decode-event []: string -> record {
    $in | decode base64 | decode | from nuon
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
            let lines = $event.payload.data | into string
            let message = $template | merge { type: output, lines: $lines }
            do $reporter.fire-output $message
        }
        { type: "error" } => {
            let lines = $event.payload.data | into string
            let message = $template | merge { type: error, lines: $lines }
            do $reporter.fire-output $message
        }
    }
}
