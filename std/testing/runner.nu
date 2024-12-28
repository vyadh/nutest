#
# This script is used by the runner to directly invoke tests from the plan data.
#
# INPUT DATA STRUCTURES
#
# suite_data:
# [
#     {
#         name: string
#         type: string
#         execute: closure
#     }
# ]
#
# Where:
#   `type` can be "test", "before-all", etc.
#   `execute` is the closure function of `type`
#

# Note: The below commands all have a prefix to avoid possible conflicts with user test files.

export def nutest-299792458-execute-suite [
    default_strategy: record<threads: int>
    suite: string
    suite_data: list
] {
    with-env { NU_TEST_SUITE_NAME: $suite } {
        nutest-299792458-execute-suite-internal $default_strategy $suite_data
    }

    # Don't output any result
    null
}

def nutest-299792458-execute-suite-internal [
    default_strategy: record<threads: int>
    suite_data: list
] {

    let plan = $suite_data | group-by type

    def find-or-default [key: string, default: record]: list -> record {
        let values = $in | get --ignore-errors $key
        if ($values | is-empty) { $default } else { $values | first }
    }
    def get-or-empty [key: string]: list -> list {
        $in | get --ignore-errors $key | default []
    }

    let strategy = $plan | find-or-default "strategy" { execute: { {} } } # Closure in record
    let before_all = $plan | get-or-empty "before-all"
    let before_each = $plan | get-or-empty "before-each"
    let after_each = $plan | get-or-empty "after-each"
    let after_all = $plan | get-or-empty "after-all"
    let tests = $plan | get-or-empty "test"
    let ignored = $plan | get-or-empty "ignore"

    # Highlight skipped tests first as there is no error handling required
    nutest-299792458-force-result $ignored "SKIP"

    try {
        let strategy = $default_strategy | merge (do $strategy.execute)
        let context_all = { } | nutest-299792458-execute-before $before_all
        $tests | nutest-299792458-execute-tests $strategy $context_all $before_each $after_each
        $context_all | nutest-299792458-execute-after $after_all
    } catch { |error|
        # This should only happen when strategy or before/after all fails, so mark all tests failed
        # Each test run has its own exception handling so is not expected to trigger this
        nutest-299792458-force-error $tests $error
    }
}

def nutest-299792458-execute-tests [
    strategy: record<threads: int>
    context_all: record
    before_each: list
    after_each: list
]: list -> nothing {

    let tests = $in

    $tests | par-each --threads $strategy.threads { |test|
        # Allow print output to be associated with specific tests by adding name to the environment
        with-env { NU_TEST_NAME: $test.name } {
            nutest-299792458-emit "start"
            nutest-299792458-execute-test $context_all $before_each $after_each $test
            nutest-299792458-emit "finish"
        }
    }
}

def nutest-299792458-execute-test [
    context_all: record
    before_each: list
    after_each: list
    test: record
] {
    let context = try {
        $context_all | nutest-299792458-execute-before $before_each
    } catch { |error|
        nutest-299792458-fail $error
        return
    }

    try {
        $context | do $test.execute
        nutest-299792458-emit "result" { status: "PASS" }
        # Note that although we have emitted PASS the after-each may still fail (see below)
    } catch { |error|
        nutest-299792458-fail $error
    }

    try {
        $context | nutest-299792458-execute-after $after_each
    } catch { |error|
        # It's possible to get a test PASS above then emit FAIL when processing after-each.
        # This needs to be handled by the reporter. We could work around it here, but since we have
        # to handle for after-all outside concurrent processing of tests anyway this is simpler.
        nutest-299792458-fail $error
    }
}

def nutest-299792458-force-result [tests: list, status: string] {
    for test in $tests {
        with-env { NU_TEST_NAME: $test.name } {
            nutest-299792458-emit "start"
            nutest-299792458-emit "result" { status: $status }
            nutest-299792458-emit "finish"
        }
    }
}

def nutest-299792458-force-error [tests: list, error: record] {
    for test in $tests {
        with-env { NU_TEST_NAME: $test.name } {
            nutest-299792458-emit "start"
            nutest-299792458-fail $error
            nutest-299792458-emit "finish"
        }
    }
}

def nutest-299792458-execute-before [items: list]: record -> record {
    let initial_context = $in
    $items | reduce --fold $initial_context { |it, acc|
        let next = (do $it.execute) | default { }
        let type = $next | describe
        if (not ($type | str starts-with "record")) {
            error make { msg: $"The before-each/all command '($it.name)' must return a record or nothing, not '($type)'" }
        }
        $acc | merge $next
    }
}

def nutest-299792458-execute-after [items: list]: record -> nothing {
    let context = $in
    for item in $items {
        $context | do $item.execute
    }
}

def nutest-299792458-fail [error: record] {
    nutest-299792458-emit "result" { status: "FAIL" }
    # Exclude raw so it can be convered to Nuon
    # Exclude debug as it reduces noise in the output
    print -e ($error | reject raw debug)
}

# Keep a reference to the internal print command
alias nutest-299792458-print = print

# Override the print command to provide context for output
export def print [--stderr (-e), --raw (-r), --no-newline (-n), ...rest: any] {
    # Capture the stream type to allow downstream rendering in the reporters
    let stream = if $stderr { "error" } else { "output" }

    # Associate the stream type with the list of data items being output
    let output = {
        stream: $stream
        items: $rest
    }

    # Encode to nuon to preserve datatypes of what is being printed for reporter-specific rendering
    # Encode to base64 to avoid newlines in any strings breaking the line-based protocol
    let encoded = $output | to nuon --raw | encode base64

    nutest-299792458-emit output { data: $encoded }
}

# TODO make payload multi-typed to avoid unnecessary record construction
def nutest-299792458-emit [type: string, payload: record = { }] {
    let event = {
        timestamp: (date now | format date "%+")
        suite: $env.NU_TEST_SUITE_NAME?
        test: $env.NU_TEST_NAME?
        type: $type
        payload: $payload
    }

    let packet = $event | to nuon --raw

    nutest-299792458-print $packet
}
