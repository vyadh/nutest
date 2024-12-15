use std/assert
source ../../std/testing/store.nu

# [strategy]
def sequential []: nothing -> record {
    { threads: 1 }
}

# [before-each]
def create-store []: record -> record {
    create
    { }
}

# [after-each]
def delete-store [] {
    delete
}

# [test]
def result-success-when-no-tests [] {
    let result = success

    assert equal $result true
}

# [test]
def result-failure-when-failing-tests [] {
    insert-result { suite: "suite", test: "pass1", result: "PASS" }
    insert-result { suite: "suite", test: "failure", result: "FAIL" }
    insert-result { suite: "suite", test: "pass2", result: "PASS" }

    let result = success

    assert equal $result false
}

# [test]
def result-success-when-only-passing-tests [] {
    insert-result { suite: "suite", test: "pass1", result: "PASS" }
    insert-result { suite: "suite", test: "pass2", result: "PASS" }

    let result = success

    assert equal $result true
}
