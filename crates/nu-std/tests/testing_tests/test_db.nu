use std/assert
use ../../std/testing/db.nu

#[before-each]
def create-db [] {
    db create
    { }
}

#[after-each]
def delete-db [] {
    db delete
}

#[test]
def duration-of-test [] {
    let start = 2024-11-22T21:45:00.00+00:00
    let end   = 2024-11-22T21:46:01.01+01:01

    db insert-result { timestamp: $start, suite: "suite", test: "test", result: "PASS" }

    assert $duration > 0
}
