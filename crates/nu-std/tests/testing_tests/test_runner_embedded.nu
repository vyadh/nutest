use std/assert
use ../../std/testing/runner_embedded.nu [
    plan-execute-suite
]

def main [] {
    execute-plan-tests
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
        { name: "test_success", success: true, output: "", error: null }
    ]
}

# TODO output not reflected in the test results
# [test]
def execute-plan-tests [] {
    let plan = [
        { name: "test_success", type: "test", execute: { success } }
        { name: "test_failure", type: "test", execute: { failure } }
        #{ name: "setup", type: "before-all", execute: { success } }
        #{ name: "cleanup", type: "after-each", execute: { success } }
    ]

    let results = plan-execute-suite $plan

    assert equal $results [
        { name: "test_success", success: true, output: "", error: null }
        { name: "test_failure", success: false, output: "", error: "This is a failure" }
        #{ name: "setup", success: true, output: "" }
        #{ name: "cleanup", success: true, output: "" }
    ]
}

def success [] {
    print -e "This is a success"
}

def failure [] {
    error make { msg: "This is a failure" }
}
