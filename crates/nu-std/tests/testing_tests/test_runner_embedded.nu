use std/assert
use ../../std/testing/runner_embedded.nu [
    plan-execute-suite
]

const success_message = "I'd much rather be happy than right any day"
const warning_message = "Don't Panic"
const failure_message = "No tea"

# [before-each]
def create-db [] -> record {
    # Given the in-process calls to the full test method, the database needs ot be closed for test
    try { nu-test-db-close }
    {}
}

# [test]
def execute-plan-empty [] {
    let plan = []
    let results = plan-execute-suite $plan

    assert equal $results []
}

# [test]
def execute-plan-test [] {
    let plan = [
        { name: "test_success", type: "test", execute: { success } }
    ]

    let results = plan-execute-suite $plan

    assert equal $results [
        {
            name: "test_success"
            success: true
            output: $success_message
            error: ""
        }
    ]
}

# [test]
def execute-plan-tests [] {
    let plan = [
        { name: "test_success", type: "test", execute: { success } }
        { name: "test_success_warning", type: "test", execute: { warning; success } }
        { name: "test_failure", type: "test", execute: { failure } }
        { name: "test_half_failure", type: "test", execute: { success; failure } }
    ]

    let results = plan-execute-suite $plan

    assert equal $results [
        { name: "test_success", success: true, output: $success_message, error: "" }
        { name: "test_success_warning", success: true, output: $success_message, error: $warning_message }
        { name: "test_failure", success: false, output: "", error: $failure_message }
        { name: "test_half_failure", success: false, output: $success_message, error: $failure_message }
    ]
}

# [test]
def execute-before-test [] {
    def get-context [] {
        {
            question: "What do you get if you multiply six by nine?"
            answer: 42
        }
    }
    def assert-context-received [] {
        assert equal $in (get-context)
    }

    let plan = [
        { name: "test-before-each", type: "test", execute: { assert-context-received } }
        { name: "before-each", type: "before-each", execute: { get-context } }
    ]

    let results = plan-execute-suite $plan

    assert equal $results [
        { name: "test-before-each", success: true, output: "", error: "" }
    ]
}

# [test]
def execute-after-test [] {
    def get-context [] {
        {
            question: "What do you get if you multiply six by nine?"
            answer: 42
        }
    }
    def assert-context-received [] {
        assert equal $in (get-context)
    }

    let plan = [
        { name: "test-each", type: "test", execute: { assert-context-received } }
        { name: "setup", type: "before-each", execute: { get-context } }
        { name: "cleanup", type: "after-each", execute: { assert-context-received } }
    ]

    let results = plan-execute-suite $plan

    assert equal $results [
        { name: "test-each", success: true, output: "", error: "" }
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
