use std/assert
use ../../std/testing/store.nu

# [strategy]
def sequential []: nothing -> record {
    {threads: 1}
}

# [before-each]
def create-store []: record -> record {
    store create
    {}
}

# [after-each]
def delete-store [] {
    store delete
}

def create-suites [] {
    store insert-result {suite: "suite1" test: "pass1" result: "PASS"}
    store insert-result {suite: "suite2" test: "pass1" result: "PASS"}
    store insert-result {suite: "suite2" test: "fail1" result: "FAIL"}
    store insert-output {suite: "suite2" test: "fail1" data: ([{stream: "output" items: ["line"]}] | to nuon)}
    store insert-result {suite: "suite3" test: "fail1" result: "PASS"}
    # Pass then fail possible for `after-all` error
    store insert-result {suite: "suite3" test: "fail1" result: "FAIL"}
}

# [test]
def query-tests [] {
    create-suites

    let results = store query

    assert equal $results [
        {suite: "suite1" test: "pass1" result: "PASS" output: []}
        {suite: "suite2" test: "fail1" result: "FAIL" output: [{stream: "output" items: ["line"]}]}
        {suite: "suite2" test: "pass1" result: "PASS" output: []}
        {suite: "suite3" test: "fail1" result: "FAIL" output: []}
    ]
}

# [test]
def query-for-specific-test [] {
    create-suites

    let results = store query-test "suite2" "fail1"

    assert equal $results [
        {suite: "suite2" test: "fail1" result: "FAIL" output: [{stream: "output" items: ["line"]}]}
    ]
}

# [test]
def query-with-before-or-after-all-output [] {
    store insert-output {suite: "suite1" test: null data: ([{stream: "output" items: ["abc"]}] | to nuon)}
    store insert-result {suite: "suite1" test: "pass1" result: "PASS"}
    store insert-result {suite: "suite1" test: "pass2" result: "PASS"}
    store insert-result {suite: "suite2" test: "pass3" result: "PASS"}

    let results = store query

    assert equal $results [
        [suite test result output];
        ["suite1" "pass1" PASS [[stream items]; [output [abc]]]]
        ["suite1" "pass2" PASS [[stream items]; [output [abc]]]]
        ["suite2" "pass3" PASS []]
    ]
}
