use std/assert

const success_message = "I'd much rather be happy than right any day"
const warning_message = "Don't Panic"
const failure_message = "No tea"

def main [] {
  execute-plan-empty
  execute-plan-test
  execute-plan-tests
  execute-before-test
  execute-after-test
}

def test-run [suite: string, plan: list<record>] -> table<suite, test, type, payload> {
    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                source std/testing/runner_embedded.nu
                source ($env.CURRENT_FILE)
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

    assert equal $results [
        [suite test type payload];
        [ "empty-suite", null, "suite-start", {} ]
        [ "empty-suite", null, "suite-end", {} ]
    ]
}

#[test]
def execute-plan-test [] {
    let plan = [
        { name: "testing", type: "test", execute: "{ success }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", null, "suite-start", {} ]
        [ "suite", "testing", "test-begin", {} ]
        [ "suite", "testing", "output", { lines: [$success_message] } ]
        [ "suite", "testing", "result", { success: true } ]
        [ "suite", "testing", "test-end", {} ]
        [ "suite", null, "suite-end", {} ]
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
        [ "suite", null, "suite-start", {} ]
        [ "suite", "test_success", "test-begin", {} ]
        [ "suite", "test_success", "output", { lines: [$success_message] } ]
        [ "suite", "test_success", "result", { success: true } ]
        [ "suite", "test_success", "test-end", {} ]
        [ "suite", "test_success_warning", "test-begin", {} ]
        [ "suite", "test_success_warning", "error", { lines: [$warning_message] } ]
        [ "suite", "test_success_warning", "output", { lines: [$success_message] } ]
        [ "suite", "test_success_warning", "result", { success: true } ]
        [ "suite", "test_success_warning", "test-end", {} ]
        [ "suite", "test_failure", "test-begin", {} ]
        [ "suite", "test_failure", "result", { success: false } ]
        [ "suite", "test_failure", "error", { lines: [$failure_message] } ]
        [ "suite", "test_failure", "test-end", {} ]
        [ "suite", "test_half_failure", "test-begin", {} ]
        [ "suite", "test_half_failure", "output", { lines: [$success_message] } ]
        [ "suite", "test_half_failure", "error", { lines: [$warning_message] } ]
        [ "suite", "test_half_failure", "result", { success: false } ]
        [ "suite", "test_half_failure", "error", { lines: [$failure_message] } ]
        [ "suite", "test_half_failure", "test-end", {} ]
        [ "suite", null, "suite-end", {} ]
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
        [ "before-suite", null, "suite-start", {} ]
        [ "before-suite", "test", "test-begin", {} ]
        [ "before-suite", "test", "output", { lines: ["What do you get if you multiply six by nine?", 42] } ]
        [ "before-suite", "test", "result", { success: true } ]
        [ "before-suite", "test", "test-end", {} ]
        [ "before-suite", null, "suite-end", {} ]
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
        [ "after-suite", null, "suite-start", {} ]
        [ "after-suite", "test", "test-begin", {} ]
        [ "after-suite", "test", "output", { lines: ["What do you get if you multiply six by nine?", 42] } ]
        [ "after-suite", "test", "result", { success: true } ]
        [ "after-suite", "test", "output", { lines: ["What do you get if you multiply six by nine?", 42] } ]
        [ "after-suite", "test", "test-end", {} ]
        [ "after-suite", null, "suite-end", {} ]
    ]
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
