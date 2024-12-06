use std/assert
source ../../std/test/store.nu

# Note: Using isolated suite to avoid concurrency conflicts with other tests
# Note: Tests for results are done in test_orchestrator and test_integration

# [before-all]
def create_store [] record -> record {
    create
    { }
}

# [after-all]
def delete_store [] {
    delete
}

# [test]
def result-failure-when-failing-tests [] {
    insert-result { suite: "suite", test: "pass1", result: "PASS" }
    insert-result { suite: "suite", test: "failure", result: "FAIL" }
    insert-result { suite: "suite", test: "pass2", result: "PASS" }

    let result = success

    assert equal $result false
}
