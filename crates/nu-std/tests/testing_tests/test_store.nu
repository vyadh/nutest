use std/assert
use ../../std/testing/db.nu

#[before-all]
def create_db [] record -> record {
    db create
    { }
}

#[after-all]
def delete_db [] {
    db delete
}

#[test]
def colour-scheme-is-used-for-stderr [] {
    db insert-result { suite: "suite", test: "test", result: "PASS" }
    db insert-output { suite: "suite", test: "test", type: "output", lines: ["normal", "message"] }
    db insert-output { suite: "suite", test: "test", type: "error", lines: ["error", "text"] }

    let results = db query { stderr-prefixing-color-scheme }

    assert equal $results ([
        {
            suite: "suite"
            test: "test"
            result: "PASS"
            output: "normal\nmessage\nSTDERR:error\ntext:STDERR"
        }
    ])
}

def stderr-prefixing-color-scheme []: record -> string {
    match $in {
        { prefix: "stderr" } => "STDERR:"
        { suffix: "stderr" } => ":STDERR"
    }
}
