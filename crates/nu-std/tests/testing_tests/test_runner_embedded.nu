use std/assert
use ../../std/testing/runner_embedded.nu [
    plan-execute-suite
]

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
        { name: "test_success", success: true, output: "", error: null }
    ]
}

# [test]
def execute-plan-tests [] {
    let plan = [
        { name: "test_success", type: "test", execute: { success } }
        { name: "test_failure", type: "test", execute: { failure } }
    ]

    let results = plan-execute-suite $plan

    assert equal $results [
        { name: "test_success", success: true, output: "", error: null }
        { name: "test_failure", success: false, output: "", error: "This is a failure" }
    ]
}

# [test]
def execute-before-test [] {
    let plan = [
        { name: "test-before-each", type: "test", execute: { assert-context-received } }
        { name: "before-each", type: "before-each", execute: { get-context } }
    ]

    let results = plan-execute-suite $plan

    assert equal $results [
        { name: "test-before-each", success: true, output: "", error: null }
    ]
}

# [test]
def execute-after-test [] {
    let plan = [
        { name: "test-each", type: "test", execute: { assert-context-received } }
        { name: "setup", type: "before-each", execute: { get-context } }
        { name: "cleanup", type: "after-each", execute: { assert-context-received } }
    ]

    let results = plan-execute-suite $plan

    assert equal $results [
        { name: "test-each", success: true, output: "", error: null }
    ]
}

def success [] {
    print -e "This is a success"
}

def failure [] {
    error make { msg: "This is a failure" }
}

def get-context [] {
    {
        question: "What do you get if you multiply six by nine?"
        answer: 42
    }
}

def assert-context-received [] {
    assert equal $in (get-context)
}
