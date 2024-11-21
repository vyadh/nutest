use std/assert

const success_message = "I'd much rather be happy than right any day"
const warning_message = "Don't Panic"
const failure_message = "No tea"

def test-run [suite: string, plan: list<record>]: nothing -> table<suite, test, type, payload> {
    let result = (
        ^$nu.current-exe
            --no-config-file
            # TODO try to avoid explicit paths but $env.CURRENT_FILE doesn't work for our generated code
            --commands $"
                source std/testing/runner.nu
                source tests/testing_tests/test_runner.nu
                plan-execute-suite-emit ($suite) ($plan)
            "
    ) | complete

    if $result.exit_code != 0 {
        error make { msg: $result.stderr }
    }

    (
        $result.stdout
            | lines
            | each { $in | from nuon | reject timestamp }
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

    assert equal $results [
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
    ]
}

#[test]
def execute-before-test [] {
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
def execute-after-test [] {
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
        [ "after-suite", "test", "output", { lines: ["What do you get if you multiply six by nine?", 42] } ]
        [ "after-suite", "test", "result", { status: "PASS" } ]
        [ "after-suite", "test", "finish", {} ]
    ]
}

#[test]
def execute-before-and-after-captures-output [] {
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
        [ "suite", "test1", "error", { lines: [$warning_message] } ]
        [ "suite", "test1", "result", { status: "PASS" } ]
        [ "suite", "test1", "finish", {} ]
        [ "suite", "test2", "start", {} ]
        [ "suite", "test2", "output", { lines: [$success_message] } ]
        [ "suite", "test2", "error", { lines: [$warning_message] } ]
        [ "suite", "test2", "result", { status: "PASS" } ]
        [ "suite", "test2", "finish", {} ]
    ]
}

#[test]
def execute-before-error-handling [] {
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
def execute-after-error-handling [] {
    let plan = [
        { name: "test", type: "test", execute: "{ noop }" }
        { name: "after-each", type: "before-each", execute: "{ failure }" }
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
