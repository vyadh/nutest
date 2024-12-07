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

export def nutest-299792458-execute-suite [suite: string, threads: int, suite_data: list] {
    with-env { NU_TEST_SUITE_NAME: $suite } {
        nutest-299792458-execute-suite-internal $threads $suite_data
    }

    # Don't output any result
    null
}

def nutest-299792458-execute-suite-internal [threads: int, suite_data: list] {
    let plan = $suite_data | group-by type

    def get-or-empty [key: string]: list -> list {
        $in | get --ignore-errors $key | default []
    }

    let before_all = $plan | get-or-empty "before-all"
    let before_each = $plan | get-or-empty "before-each"
    let after_each = $plan | get-or-empty "after-each"
    let after_all = $plan | get-or-empty "after-all"
    let tests = $plan | get-or-empty "test"
    let ignored = $plan | get-or-empty "ignore"

    # Highlight skipped tests first as there is no error handling required
    nutest-299792458-force-result $ignored "SKIP"

    try {
        let context_all = { } | nutest-299792458-execute-before $before_all
        $tests | nutest-299792458-execute-tests $threads $context_all $before_each $after_each
        $context_all | nutest-299792458-execute-after $after_all
    } catch { |error|
        # This should only happen when before/after all fails, so mark all tests failed
        # Each test run has its own exception handling so is not expected to trigger this
        nutest-299792458-force-error $tests $error
    }
}

def nutest-299792458-execute-tests [
    threads: int
    context_all: record
    before_each: list
    after_each: list
]: list -> nothing {

    let tests = $in

    $tests | par-each --threads $threads { |test|
        # Allow print output to be associated with specific tests by adding name to the environment
        with-env { NU_TEST_NAME: $test.name } {
            nutest-299792458-emit "start" { }
            nutest-299792458-execute-test $context_all $before_each $after_each $test
            nutest-299792458-emit "finish" { }
        }
    }
}

def nutest-299792458-execute-test [context_all: record, before_each: list, after_each: list, test: record] {
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
            nutest-299792458-emit "start" { }
            nutest-299792458-emit "result" { status: $status }
            nutest-299792458-emit "finish" { }
        }
    }
}

def nutest-299792458-force-error [tests: list, error: record] {
    let formatted = (nutest-299792458-format-error $error)
    for test in $tests {
        with-env { NU_TEST_NAME: $test.name } {
            nutest-299792458-emit "start" { }
            nutest-299792458-emit "result" { status: "FAIL" }
            print -e ...$formatted
            nutest-299792458-emit "finish" { }
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
    print -e ...(nutest-299792458-format-error $error)
}

def nutest-299792458-format-error [error: record]: nothing -> list<string> {
    let json = $error.json | from json
    let message = $json.msg
    let help = $json | get help?
    let labels = $json | get labels?

    if $help != null {
        [$message, $help]
    } else if ($labels != null) {
        let detail = $labels | each { |label|
            | get text
            # Not sure why this is in the middle of the error json...
            | str replace --all "originates from here" ''
        } | str join "\n"

        if ($message | str contains "Assertion failed") {
            let formatted = ($detail
                | str replace --all --regex '\n[ ]+Left' "|>Left"
                | str replace --all --regex '\n[ ]+Right' "|>Right"
                | str replace --all --regex '[\n\r]+' '\n'
                | str replace --all "|>" "\n|>")
                | str join ""
            [$message, ...($formatted | lines)]
         } else {
            [$message, ...($detail | lines)]
         }
    } else {
        [$message]
    }
}

# Keep a reference to the internal print command
alias nutest-299792458-print = print

# Override the print command to provide context for output
export def print [--stderr (-e), --raw (-r), --no-newline (-n), ...rest: any] {
    let type = if $stderr { "error" } else { "output" }
    nutest-299792458-emit $type { data: $rest }
}

def nutest-299792458-emit [type: string, payload: record] {
    let event = {
        timestamp: (date now | format date "%+")
        suite: $env.NU_TEST_SUITE_NAME?
        test: $env.NU_TEST_NAME?
        type: $type
        payload: $payload
    }

    # We need to encode the event to avoid newlines in output/error breaking the stream
    # This avoids hacks to selectively remove newlines from potentially nested structures
    let packet = $event | to nuon --raw | encode base64

    nutest-299792458-print $packet
}
