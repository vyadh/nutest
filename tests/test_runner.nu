use std/assert
use std/testing *
use ../nutest/formatter.nu
use ../nutest/theme.nu
use ../nutest/errors.nu

const success_message = "I'd much rather be happy than right any day"
const warning_message = "Don't Panic"
const failure_message = "No tea"

@test
def execute-plan-empty [] {
    let plan = []

    let results = test-run "empty-suite" $plan

    assert equal $results []
}

@test
def execute-plan-test [] {
    let plan = [
        { name: "testing", type: "test", execute: "{ success }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "testing", "start", null ]
        [ "suite", "testing", "output", { stream: "output", items: [$success_message] } ]
        [ "suite", "testing", "result", "PASS" ]
        [ "suite", "testing", "finish", null ]
    ]
}

@test
def execute-plan-with-error [] {
    let plan = [
        { name: "testing", type: "test", execute: "{ failure }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "testing", "start", null ]
        [ "suite", "testing", "result", "FAIL" ]
        [ "suite", "testing", "output", { stream: "error", items: [$failure_message] } ]
        [ "suite", "testing", "finish", null ]
    ]
}

@test
def execute-plan-tests [] {
    let plan = [
        { name: "test_success", type: "test", execute: "{ success }" }
        { name: "test_success_warning", type: "test", execute: "{ warning; success }" }
        { name: "test_failure", type: "test", execute: "{ failure }" }
        { name: "test_half_failure", type: "test", execute: "{ success; warning; failure }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results ([
        [suite test type payload];
        [ "suite", "test_success", "start", null ]
        [ "suite", "test_success", "output", { stream: "output", items: [$success_message] } ]
        [ "suite", "test_success", "result", "PASS" ]
        [ "suite", "test_success", "finish", null ]
        [ "suite", "test_success_warning", "start", null ]
        [ "suite", "test_success_warning", "output", { stream: "error", items: [$warning_message] } ]
        [ "suite", "test_success_warning", "output", { stream: "output", items: [$success_message] } ]
        [ "suite", "test_success_warning", "result", "PASS" ]
        [ "suite", "test_success_warning", "finish", null ]
        [ "suite", "test_failure", "start", null ]
        [ "suite", "test_failure", "result", "FAIL" ]
        [ "suite", "test_failure", "output", { stream: "error", items: [$failure_message] } ]
        [ "suite", "test_failure", "finish", null ]
        [ "suite", "test_half_failure", "start", null ]
        [ "suite", "test_half_failure", "output", { stream: "output", items: [$success_message] } ]
        [ "suite", "test_half_failure", "output", { stream: "error", items: [$warning_message] } ]
        [ "suite", "test_half_failure", "result", "FAIL" ]
        [ "suite", "test_half_failure", "output", { stream: "error", items: [$failure_message] } ]
        [ "suite", "test_half_failure", "finish", null ]
    ] | sort-by suite test)
}

@test
def execute-test-types-basic [] {
    let plan = [
        { name: "bool", type: "test", execute: "{ print true }" }
        { name: "datetime", type: "test", execute: "{ print 2022-02-02T14:30:00+05:00 }" }
        { name: "duration", type: "test", execute: "{ print 2min }" }
        { name: "filesize", type: "test", execute: "{ print 8KiB }" }
        { name: "float", type: "test", execute: "{ print 0.5 }" }
        { name: "int", type: "test", execute: "{ print 1 }" }
    ]

    let results = test-run "types" $plan | where type == "output"

    assert equal $results [
        [suite test type payload];
        [ "types", "bool", "output", { stream: "output", items: [true] } ]
        [ "types", "datetime", "output", { stream: "output", items: [2022-02-02T14:30:00+05:00] } ]
        [ "types", "duration", "output", { stream: "output", items: [2min] } ]
        [ "types", "filesize", "output", { stream: "output", items: [8KiB] } ]
        [ "types", "float", "output", { stream: "output", items: [0.5] } ]
        [ "types", "int", "output", { stream: "output", items: [1] } ]
    ]
}

@test
def execute-test-types-structured [] {
    let plan = [
        { name: "list", type: "test", execute: "{ print [1, '2', 3min] }" }
        { name: "record", type: "test", execute: "{ print { a: 1, b: 2 } }" }
    ]

    let results = test-run "types" $plan | where type in ["result", "output", "error"]

    assert equal $results [
        [suite test type payload];
        [ "types", "list", "output", { stream: "output", items: [[1, "2", 3min]] } ]
        [ "types", "list", "result", "PASS" ]
        [ "types", "record", "output", { stream: "output", items: [{a: 1, b: 2}] } ]
        [ "types", "record", "result", "PASS" ]
    ]
}

@test
def execute-test-with-multiple-lines [] {
    let plan = [
        { name: "multi-print", type: "test", execute: "{ print 'one'; print 'two' }" }
        { name: "print-rest", type: "test", execute: "{ print 'one' 'two' }" }
        { name: "with-newlines", type: "test", execute: "{ print 'one\ntwo' }" }
    ]

    let results = test-run "suite" $plan | where type == "output"

    assert equal $results [
        [suite test type payload];
        [ "suite", "multi-print", "output", { stream: "output", items: ["one"] } ]
        [ "suite", "multi-print", "output", { stream: "output", items: ["two"] } ]
        [ "suite", "print-rest", "output", { stream: "output", items: ["one", "two"] } ]
        [ "suite", "with-newlines", "output", { stream: "output", items: ["one\ntwo"] } ]
    ]
}

@test
def execute-test-with-multiple-lines-deep [] {
    let plan = [
        { name: "list", type: "test", execute: "{ print [1, '2\n3', 4min] }" }
        { name: "record", type: "test", execute: "{ print { a: 1, b: '2\n3' } }" }
    ]

    let results = test-run "types" $plan | where type in ["result", "output", "error"]

    assert equal $results [
        [suite test type payload];
        [ "types", "list", "output", { stream: "output", items: [[1, "2\n3", 4min]] } ]
        [ "types", "list", "result", "PASS" ]
        [ "types", "record", "output", { stream: "output", items: [{a: 1, b: "2\n3"}] } ]
        [ "types", "record", "result", "PASS" ]
    ]
}

@test
def execute-before-each-test [] {
    let plan = [
        { name: "test", type: "test", execute: "{ assert-context-received }" }
        { name: "before-each", type: "before-each", execute: "{ get-context }" }
    ]

    let results = test-run "before-suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "before-suite", "test", "start", null ]
        [ "before-suite", "test", "output", { stream: "output", items: ["What do you get if you multiply six by nine?", 42] } ]
        [ "before-suite", "test", "result", "PASS" ]
        [ "before-suite", "test", "finish", null ]
    ]
}

@test
def execute-after-each-test [] {
    let plan = [
        { name: "test", type: "test", execute: "{ assert-context-received }" }
        { name: "setup", type: "before-each", execute: "{ get-context }" }
        { name: "cleanup", type: "after-each", execute: "{ assert-context-received }" }
    ]

    let results = test-run "after-suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "after-suite", "test", "start", null ]
        [ "after-suite", "test", "output", { stream: "output", items: ["What do you get if you multiply six by nine?", 42] } ]
        [ "after-suite", "test", "result", "PASS" ]
        [ "after-suite", "test", "output", { stream: "output", items: ["What do you get if you multiply six by nine?", 42] } ]
        [ "after-suite", "test", "finish", null ]
    ]
}

@test
def execute-before-and-after-each-captures-output [] {
    let plan = [
        { name: "before-each", type: "before-each", execute: "{ success; get-context }" }
        { name: "test1", type: "test", execute: "{ noop }" }
        { name: "test2", type: "test", execute: "{ noop }" }
        { name: "after-each", type: "after-each", execute: "{ warning }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "test1", "start", null ]
        [ "suite", "test1", "output", { stream: "output", items: [$success_message] } ]
        [ "suite", "test1", "result", "PASS" ]
        [ "suite", "test1", "output", { stream: "error", items: [$warning_message] } ]
        [ "suite", "test1", "finish", null ]
        [ "suite", "test2", "start", null ]
        [ "suite", "test2", "output", { stream: "output", items: [$success_message] } ]
        [ "suite", "test2", "result", "PASS" ]
        [ "suite", "test2", "output", { stream: "error", items: [$warning_message] } ]
        [ "suite", "test2", "finish", null ]
    ]
}

# This kind output is not associated with tests by the runner
@test
def execute-before-and-after-all-captures-output [] {
    let plan = [
        { name: "before-all", type: "before-all", execute: "{ print 1; print -e 2; get-context }" }
        { name: "test1", type: "test", execute: "{ print 3; print -e 4 }" }
        { name: "test2", type: "test", execute: "{ print 5; print -e 6 }" }
        { name: "after-all", type: "after-all", execute: "{ print 7; print -e 8 }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "test1", "start", null ]
        [ "suite", "test1", "output", { stream: "output", items: [3] } ]
        [ "suite", "test1", "output", { stream: "error", items: [4] } ]
        [ "suite", "test1", "result", "PASS" ]
        [ "suite", "test1", "finish", null ]
        [ "suite", "test2", "start", null ]
        [ "suite", "test2", "output", { stream: "output", items: [5] } ]
        [ "suite", "test2", "output", { stream: "error", items: [6] } ]
        [ "suite", "test2", "result", "PASS" ]
        [ "suite", "test2", "finish", null ]
        # Ordering is due to this suite performing sorting due to parallelism
        [ "suite", null, "output", { stream: "output", items: [1] } ]
        [ "suite", null, "output", { stream: "error", items: [2] } ]
        [ "suite", null, "output", { stream: "output", items: [7] } ]
        [ "suite", null, "output", { stream: "error", items: [8] } ]
     ]
}

@test
def execute-before-each-error-handling [] {
    let plan = [
        { name: "test", type: "test", execute: "{ noop }" }
        { name: "before-each", type: "before-each", execute: "{ failure }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "test", "start", null ]
        [ "suite", "test", "result", "FAIL" ]
        [ "suite", "test", "output", { stream: "error", items: [$failure_message] } ]
        [ "suite", "test", "finish", null ]
    ]
}

@test
def execute-after-each-error-handling [] {
    let plan = [
        { name: "test", type: "test", execute: "{ noop }" }
        { name: "after-each", type: "after-each", execute: "{ failure }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "test", "start", null ]
        [ "suite", "test", "result", "PASS" ] # The test passed
        [ "suite", "test", "result", "FAIL" ] # But after-each failed
        [ "suite", "test", "output", { stream: "error", items: [$failure_message] } ]
        [ "suite", "test", "finish", null ]
    ]
}

@test
def execute-before-all-error-handling [] {
    let plan = [
        { name: "test1", type: "test", execute: "{ noop }" }
        { name: "test2", type: "test", execute: "{ noop }" }
        { name: "before-all", type: "before-all", execute: "{ failure }" }
    ]

    let results = test-run "suite" $plan

    assert equal $results [
        [suite test type payload];
        [ "suite", "test1", "start", null ]
        [ "suite", "test1", "result", "FAIL" ]
        [ "suite", "test1", "output", { stream: "error", items: [$failure_message] } ]
        [ "suite", "test1", "finish", null ]
        [ "suite", "test2", "start", null ]
        [ "suite", "test2", "result", "FAIL" ]
        [ "suite", "test2", "output", { stream: "error", items: [$failure_message] } ]
        [ "suite", "test2", "finish", null ]
    ]
}

@test
def execute-after-all-error-handling [] {
    let plan = [
        { name: "test1", type: "test", execute: "{ noop }" }
        { name: "test2", type: "test", execute: "{ noop }" }
        { name: "after-all", type: "after-all", execute: "{ failure }" }
    ]

    let results = test-run "suite" $plan

    # Note how the test passes first and then fails because of the after-all failure
    assert equal $results [
        [suite test type payload];
        [ "suite", "test1", "start", null ]
        [ "suite", "test1", "result", "PASS" ]
        [ "suite", "test1", "finish", null ]
        [ "suite", "test1", "start", null ]
        [ "suite", "test1", "result", "FAIL" ]
        [ "suite", "test1", "output", { stream: "error", items: [$failure_message] } ]
        [ "suite", "test1", "finish", null ]
        [ "suite", "test2", "start", null ]
        [ "suite", "test2", "result", "PASS" ]
        [ "suite", "test2", "finish", null ]
        [ "suite", "test2", "start", null ]
        [ "suite", "test2", "result", "FAIL" ]
        [ "suite", "test2", "output", { stream: "error", items: [$failure_message] } ]
        [ "suite", "test2", "finish", null ]
    ]
}

def noop [] {
}

def success [] {
    print $success_message
}

def warning [] {
    print -e $warning_message
}

def failure [] {
    error make { msg: $failure_message }
}

def get-context [] {
    {
        question: "What do you get if you multiply six by nine?"
        answer: 42
    }
}

def assert-context-received [] {
    let context = $in
    print ($context | get question) ($context | get answer)
    assert equal $context (get-context)
}

@test
def signature-before-that-returns-nothing [] {
    let plan = [
        { name: "all-has-output", type: "before-all", execute: "{ { value1: 'preserved-all' } }" }
        { name: "all-no-output", type: "before-all", execute: "{ null }" }
        { name: "each-has-output", type: "before-each", execute: "{ { value2: 'preserved-each' } }" }
        { name: "each-no-output", type: "before-each", execute: "{ null }" }
        { name: "test", type: "test", execute: "{ print $in.value1; print $in.value2 }" }
    ]

    let result = test-run "suite" $plan |
        where type in ["result", "output", "error"]

    assert equal $result [
        [suite test type payload];
        [ "suite", "test", "output", { stream: "output", items: [ "preserved-all" ] } ]
        [ "suite", "test", "output", { stream: "output", items: [ "preserved-each" ] } ]
        [ "suite", "test", "result", "PASS" ]
    ]
}

@test
def signature-after-that-accepts-nothing [] {
    let plan = [
        { name: "some-context", type: "before-all", execute: "{ { key: 'value' } }" }
        { name: "test", type: "test", execute: "{ noop }" }
        { name: "each-no-input", type: "after-each", execute: "{ after-no-input }" }
        { name: "all-no-input", type: "after-all", execute: "{ after-no-input }" }
    ]

    let result = test-run "suite" $plan |
        where type in ["result", "output", "error"]

    assert equal $result [
        [suite test type payload];
        [ "suite", "test", "result", "PASS" ]
    ]
}

def after-no-input []: nothing -> nothing {
}

@test
def signature-before-each-that-returns-non-record [] {
    let plan = [
        { name: "returns-string", type: "before-each", execute: "{ 'value' }" }
        { name: "test", type: "test", execute: "{ noop }" }
    ]

    let result = test-run "suite" $plan |
        where type in ["result", "output", "error"]

    assert equal $result [
        [suite test type payload];
        [ "suite", "test", "result", "FAIL" ]
        [ "suite", "test", "output", { stream: "error", items: [
            "The before-each/all command 'returns-string' must return a record or nothing, not 'string'"
        ] } ]
    ]
}

@test
def signature-before-all-that-returns-non-record [] {
    let plan = [
        { name: "returns-string", type: "before-all", execute: "{ 'value' }" }
        { name: "test", type: "test", execute: "{ noop }" }
    ]

    let result = test-run "suite" $plan |
        where type in ["result", "output", "error"]

    assert equal $result [
        [suite test type payload];
        [ "suite", "test", "result", "FAIL" ]
        [ "suite", "test", "output", { stream: "error", items: [
            "The before-each/all command 'returns-string' must return a record or nothing, not 'string'"
        ] } ]
    ]
}

@test
def signature-after-that-accepts-non-record [] {
    let plan = [
        [name, type, execute];
        ["context", "before-all", "{ { key: context } }"]
        ["test", "test", "{ noop }"]
        ["accepts-string", "after-all", "{ accepts-string }"]
    ]

    let result = test-run "suite" $plan |
        where type in ["result", "output"]

    if (supports-non-record-types) {
        assert equal $result [
            [suite test type payload];
            # Nushell currently allows this, perhaps because we're not using the type as a string.
            # We still test to capture unintended behaviour changes.
            [
                "suite"
                "test"
                "result"
                "PASS"
            ]
            [
                "suite"
                "test"
                "result"
                "FAIL"
            ]
            [
                "suite"
                "test"
                "output"
                { stream: "error", items: ["Input type not supported."] }
            ]
        ]
    }
}

def supports-non-record-types []: nothing -> bool {
    let version_str = version | get version
    if ($version_str | str contains "nightly") {
        return true
    } else {
        # Only supported on Nushell >= 0.101.1
        let version = $version_str | split row '.' | each { into int }
        $version.0 >= 0 and $version.1 >= 101 and $version.2 >= 1
    }
}

def accepts-string []: string -> nothing {
    print $in
}

@test
def full-cycle-context [] {
    let plan = [
        { name: "before-all", type: "before-all", execute: "{ fc-before-all }" }
        { name: "before-each", type: "before-each", execute: "{ fc-before-each }" }
        { name: "test1", type: "test", execute: "{ fc-test }" }
        { name: "test2", type: "test", execute: "{ fc-test }" }
        { name: "after-each", type: "after-each", execute: "{ fc-after-each }" }
        { name: "after-all", type: "after-all", execute: "{ fc-after-all }" }
    ]

    let results = test-run "full-cycle" $plan

    assert equal $results ([
        [suite test type payload];
        # Before all is only executed once at the beginning
        [ "full-cycle", null, "output", { stream: "output", items: ["ba"] } ]

        [ "full-cycle", "test1", "start", null ]
        [ "full-cycle", "test1", "output", { stream: "output", items: [ "b" ] } ]
        [ "full-cycle", "test1", "output", { stream: "output", items: [ "t" ] } ]
        [ "full-cycle", "test1", "result", "PASS" ]
        [ "full-cycle", "test1", "output", { stream: "output", items: [ "a" ] } ]
        [ "full-cycle", "test1", "finish", null ]

        [ "full-cycle", "test2", "start", null ]
        [ "full-cycle", "test2", "output", { stream: "output", items: [ "b" ] } ]
        [ "full-cycle", "test2", "output", { stream: "output", items: [ "t" ] } ]
        [ "full-cycle", "test2", "result", "PASS" ]
        [ "full-cycle", "test2", "output", { stream: "output", items: [ "a" ] } ]
        [ "full-cycle", "test2", "finish", null ]

        # After all is only executed once at the end
        [ "full-cycle", null, "output", { stream: "output", items: ["aa"] } ]
    ] | sort-by suite test)
}

def fc-before-all []: record -> record {
    print "ba"
    { before-all: true }
}

def fc-before-each []: record -> record {
    print "b"

    $in | merge { before: true }
}

def fc-test []: record -> nothing {
    print "t"
    assert equal $in {
        before-all: true
        before: true
    }
}

def fc-after-each []: record -> nothing {
    print "a"
}

def fc-after-all []: record -> nothing {
    print "aa"
}

def test-run [suite: string, plan: list<record>]: nothing -> table<suite, test, type, payload> {
    const this_file = path self
    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use nutest/runner.nu *
                source ($this_file)
                nutest-299792458-execute-suite { threads: 0 } ($suite) ($plan)
            "
    ) | complete

    if $result.exit_code != 0 {
        error make { msg: $result.stderr }
    }

    (
        $result.stdout
            | lines
            | each { $in | from nuon }
            | sort-by suite test
            | reject timestamp
            | update payload { |row|
                if ($row.type in ["output", "error"]) {
                    # Decode output to testable format
                    ($row.payload | decode-output )
                } else {
                    $row.payload
                }
            }
    )
}

def decode-output []: string -> record<stream: string, items: list<any>> {
    $in | decode base64 | decode | from nuon | reformat-errors
}

def reformat-errors []: record<stream: string, items: list<any>> -> record<stream: string, items: list<any>> {
    $in | update items { |event|
        $event.items | each { |item|
            if ($item | looks-like-error) {
                $item | errors unwrap-error | get msg
            } else {
                $item
            }
        }
    }
}

def looks-like-error []: any -> bool {
    let value = $in
    if ($value | describe | str starts-with "record") {
        let columns = $value | columns
        ("msg" in $columns) and ("rendered" in $columns) and ("json" in $columns)
    } else {
        false
    }
}
