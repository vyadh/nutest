use std assert

const success_message = "I'd much rather be happy than right any day"
const warning_message = "Don't Panic"
const failure_message = "No tea"

def test-run [suite: string, plan: list<record>]: nothing -> table<suite, test, type, payload> {
    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                source std/test/runner.nu
                source tests/test/test_runner.nu
                nutest-299792458-execute-suite ($suite) 0 ($plan)
            "
    ) | complete

    if $result.exit_code != 0 {
        error make { msg: $result.stderr }
    }

    (
        $result.stdout
            | lines
            | each { $in | from nuon }
            | sort-by suite test
            | reject timestamp
    )
}

#[test]
def execute-plan-empty [] {
    let plan = []

    let results = test-run "empty-suite" $plan

    assert equal $results []
}

#[test]
def execute-plan-test [] {
    let plan = [
        { name: "testing", type: "test", execute: "{ success }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "testing", "start", {} ]
        [ "suite", "testing", "output", { lines: [$success_message] } ]
        [ "suite", "testing", "result", { status: "PASS" } ]
        [ "suite", "testing", "finish", {} ]
    ]
}

#[test]
def execute-plan-tests [] {
    let plan = [
        { name: "test_success", type: "test", execute: "{ success }" }
        { name: "test_success_warning", type: "test", execute: "{ warning; success }" }
        { name: "test_failure", type: "test", execute: "{ failure }" }
        { name: "test_half_failure", type: "test", execute: "{ success; warning; failure }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results ([
        [suite test type payload];
        [ "suite", "test_success", "start", {} ]
        [ "suite", "test_success", "output", { lines: [$success_message] } ]
        [ "suite", "test_success", "result", { status: "PASS" } ]
        [ "suite", "test_success", "finish", {} ]
        [ "suite", "test_success_warning", "start", {} ]
        [ "suite", "test_success_warning", "error", { lines: [$warning_message] } ]
        [ "suite", "test_success_warning", "output", { lines: [$success_message] } ]
        [ "suite", "test_success_warning", "result", { status: "PASS" } ]
        [ "suite", "test_success_warning", "finish", {} ]
        [ "suite", "test_failure", "start", {} ]
        [ "suite", "test_failure", "result", { status: "FAIL" } ]
        [ "suite", "test_failure", "error", { lines: [$failure_message] } ]
        [ "suite", "test_failure", "finish", {} ]
        [ "suite", "test_half_failure", "start", {} ]
        [ "suite", "test_half_failure", "output", { lines: [$success_message] } ]
        [ "suite", "test_half_failure", "error", { lines: [$warning_message] } ]
        [ "suite", "test_half_failure", "result", { status: "FAIL" } ]
        [ "suite", "test_half_failure", "error", { lines: [$failure_message] } ]
        [ "suite", "test_half_failure", "finish", {} ]
    ] | sort-by suite test)
}

#[test]
def execute-before-each-test [] {
    let plan = [
        { name: "test", type: "test", execute: "{ assert-context-received }" }
        { name: "before-each", type: "before-each", execute: "{ get-context }" }
    ]

    let results = test-run "before-suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "before-suite", "test", "start", {} ]
        [ "before-suite", "test", "output", { lines: ["What do you get if you multiply six by nine?", 42] } ]
        [ "before-suite", "test", "result", { status: "PASS" } ]
        [ "before-suite", "test", "finish", {} ]
    ]
}

#[test]
def execute-after-each-test [] {
    let plan = [
        { name: "test", type: "test", execute: "{ assert-context-received }" }
        { name: "setup", type: "before-each", execute: "{ get-context }" }
        { name: "cleanup", type: "after-each", execute: "{ assert-context-received }" }
    ]

    let results = test-run "after-suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "after-suite", "test", "start", {} ]
        [ "after-suite", "test", "output", { lines: ["What do you get if you multiply six by nine?", 42] } ]
        [ "after-suite", "test", "result", { status: "PASS" } ]
        [ "after-suite", "test", "output", { lines: ["What do you get if you multiply six by nine?", 42] } ]
        [ "after-suite", "test", "finish", {} ]
    ]
}

#[test]
def execute-before-and-after-each-captures-output [] {
    let plan = [
        { name: "before-each", type: "before-each", execute: "{ success; get-context }" }
        { name: "test1", type: "test", execute: "{ noop }" }
        { name: "test2", type: "test", execute: "{ noop }" }
        { name: "after-each", type: "after-each", execute: "{ warning }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "test1", "start", {} ]
        [ "suite", "test1", "output", { lines: [$success_message] } ]
        [ "suite", "test1", "result", { status: "PASS" } ]
        [ "suite", "test1", "error", { lines: [$warning_message] } ]
        [ "suite", "test1", "finish", {} ]
        [ "suite", "test2", "start", {} ]
        [ "suite", "test2", "output", { lines: [$success_message] } ]
        [ "suite", "test2", "result", { status: "PASS" } ]
        [ "suite", "test2", "error", { lines: [$warning_message] } ]
        [ "suite", "test2", "finish", {} ]
    ]
}

#[test]
def execute-before-each-error-handling [] {
    let plan = [
        { name: "test", type: "test", execute: "{ noop }" }
        { name: "before-each", type: "before-each", execute: "{ failure }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "test", "start", {} ]
        [ "suite", "test", "result", { status: "FAIL" } ]
        [ "suite", "test", "error", { lines: [$failure_message] } ]
        [ "suite", "test", "finish", {} ]
    ]
}

#[test]
def execute-after-each-error-handling [] {
    let plan = [
        { name: "test", type: "test", execute: "{ noop }" }
        { name: "after-each", type: "after-each", execute: "{ failure }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "test", "start", {} ]
        [ "suite", "test", "result", { status: "PASS" } ] # The test passed
        [ "suite", "test", "result", { status: "FAIL" } ] # But after-each failed
        [ "suite", "test", "error", { lines: [$failure_message] } ]
        [ "suite", "test", "finish", {} ]
    ]
}

#[test]
def execute-before-all-error-handling [] {
    let plan = [
        { name: "test1", type: "test", execute: "{ noop }" }
        { name: "test2", type: "test", execute: "{ noop }" }
        { name: "before-all", type: "before-all", execute: "{ failure }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "test1", "start", {} ]
        [ "suite", "test1", "result", { status: "FAIL" } ]
        [ "suite", "test1", "error", { lines: [$failure_message] } ]
        [ "suite", "test1", "finish", {} ]
        [ "suite", "test2", "start", {} ]
        [ "suite", "test2", "result", { status: "FAIL" } ]
        [ "suite", "test2", "error", { lines: [$failure_message] } ]
        [ "suite", "test2", "finish", {} ]
    ]
}

#[test]
def execute-after-all-error-handling [] {
    let plan = [
        { name: "test1", type: "test", execute: "{ noop }" }
        { name: "test2", type: "test", execute: "{ noop }" }
        { name: "after-all", type: "after-all", execute: "{ failure }" }
    ]

    let results = test-run "suite" $plan

    # Note how the test passes first and then fails because of the after-all failure
    assert equal $results [
        [suite test type payload];
        [ "suite", "test1", "start", {} ]
        [ "suite", "test1", "result", { status: "PASS" } ]
        [ "suite", "test1", "finish", {} ]
        [ "suite", "test1", "start", {} ]
        [ "suite", "test1", "result", { status: "FAIL" } ]
        [ "suite", "test1", "error", { lines: [$failure_message] } ]
        [ "suite", "test1", "finish", {} ]
        [ "suite", "test2", "start", {} ]
        [ "suite", "test2", "result", { status: "PASS" } ]
        [ "suite", "test2", "finish", {} ]
        [ "suite", "test2", "start", {} ]
        [ "suite", "test2", "result", { status: "FAIL" } ]
        [ "suite", "test2", "error", { lines: [$failure_message] } ]
        [ "suite", "test2", "finish", {} ]
    ]
}

def noop [] {
}

def success [] {
    print $success_message
}

def warning [] {
    print -e $warning_message
}

def failure [] {
    error make { msg: $failure_message }
}

def get-context [] {
    {
        question: "What do you get if you multiply six by nine?"
        answer: 42
    }
}

def assert-context-received [] {
    let context = $in
    print ($context | get question) ($context | get answer)
    assert equal $context (get-context)
}

#[test]
def signature-before-that-returns-nothing [] {
    let plan = [
        { name: "all-has-output", type: "before-all", execute: "{ { value1: 'preserved-all' } }" }
        { name: "all-no-output", type: "before-all", execute: "{ null }" }
        { name: "each-has-output", type: "before-each", execute: "{ { value2: 'preserved-each' } }" }
        { name: "each-no-output", type: "before-each", execute: "{ null }" }
        { name: "test", type: "test", execute: "{ print $in.value1; print $in.value2 }" }
    ]

    let result = test-run "suite" $plan |
        where type in ["result", "output", "error"]

    assert equal $result [
        [suite test type payload];
        [ "suite", "test", "output", { lines: [ "preserved-all" ] } ]
        [ "suite", "test", "output", { lines: [ "preserved-each" ] } ]
        [ "suite", "test", "result", { status: "PASS" } ]
    ]
}

#[test]
def signature-after-that-accepts-nothing [] {
    let plan = [
        { name: "some-context", type: "before-all", execute: "{ { key: 'value' } }" }
        { name: "test", type: "test", execute: "{ noop }" }
        { name: "each-no-input", type: "after-each", execute: "{ after-no-input }" }
        { name: "all-no-input", type: "after-all", execute: "{ after-no-input }" }
    ]

    let result = test-run "suite" $plan |
        where type in ["result", "output", "error"]

    assert equal $result [
        [suite test type payload];
        [ "suite", "test", "result", { status: "PASS" } ]
    ]
}

def after-no-input []: nothing -> nothing {
}

#[test]
def signature-before-each-that-returns-non-record [] {
    let plan = [
        { name: "returns-string", type: "before-each", execute: "{ 'value' }" }
        { name: "test", type: "test", execute: "{ }" }
    ]

    let result = test-run "suite" $plan |
        where type in ["result", "output", "error"]

    assert equal $result [
        [suite test type payload];
        [ "suite", "test", "result", { status: "FAIL" } ]
        [ "suite", "test", "error", { lines: [
            "The before-each/all function 'returns-string' must return a record or nothing, not 'string'"
        ] } ]
    ]
}

#[test]
def signature-before-all-that-returns-non-record [] {
    let plan = [
        { name: "returns-string", type: "before-all", execute: "{ 'value' }" }
        { name: "test", type: "test", execute: "{ }" }
    ]

    let result = test-run "suite" $plan |
        where type in ["result", "output", "error"]

    assert equal $result [
        [suite test type payload];
        [ "suite", "test", "result", { status: "FAIL" } ]
        [ "suite", "test", "error", { lines: [
            "The before-each/all function 'returns-string' must return a record or nothing, not 'string'"
        ] } ]
    ]
}

#[test]
def signature-after-that-accepts-non-record [] {
    let plan = [
        { name: "test", type: "test", execute: "{ }" }
        { name: "accepts-string", type: "after-all", execute: "{ accepts-string }" }
    ]

    let result = test-run "suite" $plan |
        where type in ["result"]

    assert equal $result [
        [suite test type payload];
        [ "suite", "test", "result", { status: "FAIL" } ]
        # The error message is not checked because it's generated from the core.
        # Currently "Can't convert to Closure". This is not a great error message,
        # however short of doing additional error interception or pre-checking via
        # `scope commands` there's not much we can do.
    ]
}

def accepts-string []: string -> nothing {
    print $in
}

#[test]
def full-cycle-context [] {
    let plan = [
        { name: "before-all", type: "before-all", execute: "{ fc-before-all }" }
        { name: "before-each", type: "before-each", execute: "{ fc-before-each }" }
        { name: "test1", type: "test", execute: "{ fc-test }" }
        { name: "test2", type: "test", execute: "{ fc-test }" }
        { name: "after-each", type: "after-each", execute: "{ fc-after-each }" }
        { name: "after-all", type: "after-all", execute: "{ fc-after-all }" }
    ]

    let results = test-run "full-cycle" $plan

    assert equal $results ([
        [suite test type payload];
        # Before all is only executed once at the beginning
        [ "full-cycle", "full-cycle-context", "output", { lines: ["ba"] } ]

        [ "full-cycle", "test1", "start", {} ]
        [ "full-cycle", "test1", "output", { lines: [ "b" ] } ]
        [ "full-cycle", "test1", "output", { lines: [ "t" ] } ]
        [ "full-cycle", "test1", "result", { status: "PASS" } ]
        [ "full-cycle", "test1", "output", { lines: [ "a" ] } ]
        [ "full-cycle", "test1", "finish", {} ]

        [ "full-cycle", "test2", "start", {} ]
        [ "full-cycle", "test2", "output", { lines: [ "b" ] } ]
        [ "full-cycle", "test2", "output", { lines: [ "t" ] } ]
        [ "full-cycle", "test2", "result", { status: "PASS" } ]
        [ "full-cycle", "test2", "output", { lines: [ "a" ] } ]
        [ "full-cycle", "test2", "finish", {} ]

        # After all is only executed once at the end
        [ "full-cycle", "full-cycle-context", "output", { lines: ["aa"] } ]
    ] | sort-by suite test)
}

def fc-before-all []: record -> record {
    print "ba"
    { before-all: true }
}

def fc-before-each []: record -> record {
    print "b"

    $in | merge { before: true }
}

def fc-test []: record -> nothing {
    print "t"
    assert equal $in {
        before-all: true
        before: true
    }
}

def fc-after-each []: record -> nothing {
    print "a"
}

def fc-after-all []: record -> nothing {
    print "aa"
}
