use std/assert
source ../../std/testing/store.nu

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
def result-success-when-no-tests [] {
    let result = success

    assert equal $result true
}
