use std/assert
source ../../std/testing/store.nu

# Note: Using isolated suite to avoid concurrency conflicts with other tests
# Note: Tests for results are done in test_orchestrator and test_integration

# [before-all]
def create-store []: record -> record {
    create

    insert-result { suite: "suite1", test: "pass1", result: "PASS" }
    insert-result { suite: "suite2", test: "pass1", result: "PASS" }
    insert-result { suite: "suite2", test: "fail1", result: "FAIL" }
    insert-output { suite: "suite2", test: "fail1", data: ([{stream: "output", items: ["line"]}] | to nuon) }
    insert-result { suite: "suite3", test: "fail1", result: "PASS" }
    # Pass then fail possible for `after-all` error
    insert-result { suite: "suite3", test: "fail1", result: "FAIL" }

    { }
}

# [after-all]
def delete-store [] {
    delete
}

# [test]
def query-tests [] {
    let results = query

    assert equal $results [
        { suite: "suite1", test: "pass1", result: "PASS", output: [] }
        { suite: "suite2", test: "fail1", result: "FAIL", output: [{ stream: "output", items: ["line"]}] }
        { suite: "suite2", test: "pass1", result: "PASS", output: [] }
        { suite: "suite3", test: "fail1", result: "FAIL", output: [] }
    ]
}

# [test]
def query-for-specific-test [] {
    let results = query-test "suite2" "fail1"

    assert equal $results [
        { suite: "suite2", test: "fail1", result: "FAIL", output: [{ stream: "output", items: ["line"] }]}
    ]
}
