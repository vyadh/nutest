use std/assert
use ../../std/testing/store.nu

#[before-all]
def create_store [] record -> record {
    store create
    { }
}

#[after-all]
def delete_store [] {
    store delete
}

#[test]
def colour-scheme-is-used-for-stderr [] {
    store insert-result { suite: "suite", test: "test", result: "PASS" }
    store insert-output { suite: "suite", test: "test", type: "output", lines: ["normal", "message"] }
    store insert-output { suite: "suite", test: "test", type: "error", lines: ["error", "text"] }

    let results = store query { stderr-prefixing-color-scheme }

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
