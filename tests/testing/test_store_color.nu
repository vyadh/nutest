use std/assert
source ../../std/testing/store.nu

# Note: Using isolated suite to avoid concurrency conflicts with other tests

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
def colour-scheme-is-used-for-stderr [] {
    insert-result { suite: "suite", test: "test", result: "PASS" }
    insert-output { suite: "suite", test: "test", type: "output", lines: ["normal", "message"] }
    insert-output { suite: "suite", test: "test", type: "error", lines: ["error", "text"] }

    let results = query { stderr-prefixing-color-scheme }

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
