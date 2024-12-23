use std/assert
source ../../std/testing/store.nu

# Note: Using isolated suite to avoid concurrency conflicts with other tests

# [before-all]
def create-store []: record -> record {
    create
    { }
}

# [after-all]
def delete-store [] {
    delete
}

# [ignore]
def theme-is-used-for-stderr [] {
    insert-result { suite: "suite", test: "test", result: "PASS" }
    insert-output { suite: "suite2", test: "test", data: ([{stream: "output", items: ["normal", "message"]}] | to nuon) }
    insert-output { suite: "suite2", test: "test", data: ([{stream: "error", items: ["error", "text"]}] | to nuon) }

    # TODO need to support in renders
    #let results = query { stderr-prefixing-theme }
    let results = query

    assert equal $results ([
        {
            suite: "suite"
            test: "test"
            result: "PASS"
            output: "normal\nmessage\nSTDERR:error\ntext:STDERR"
        }
    ])
}

def stderr-prefixing-theme []: record -> string {
    match $in {
        { prefix: "stderr" } => "STDERR:"
        { suffix: "stderr" } => ":STDERR"
    }
}
