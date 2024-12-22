use std/assert
use harness.nu

# This suite ensures that various printed outputs are represented as would be
# expected if the test code was being run directly and interactively.

# [before-all]
def setup-tests []: record -> record {
    $in | harness setup-tests
}

# [after-all]
def cleanup-tests []: record -> nothing {
    $in | harness cleanup-tests
}

# [before-each]
def setup-test []: record -> record {
    $in | harness setup-test
}

# [after-each]
def cleanup-test []: record -> nothing {
    $in | harness cleanup-test
}

# [test]
def nulls [] {
    let code = { print null }
    let output = $in | run $code
    assert equal $output []

    let code = { print null null null}
    let output = $in | run $code
    assert equal $output []
}

# [test]
def numbers [] {
    let code = { print 1 }
    let output = $in | run $code
    assert equal $output [1]

    let code = { print 1 2 3}
    let output = $in | run $code
    assert equal $output [1, 2, 3]
}

# [test]
def strings [] {
    let code = { print "str" }
    let output = $in | run $code
    assert equal $output ["str"]

    let code = { print "one" "two" "three" }
    let output = $in | run $code
    assert equal $output ["one", "two", "three"]
}

# [test]
def durations [] {
    let code = { print 2min }
    let output = $in | run $code
    assert equal $output [2min]
}

# [test]
def lists [] {
    let code = { print [] }
    let output = $in | run $code
    assert equal $output [[]]

    let code = { print [1, "two", 3] }
    let output = $in | run $code
    assert equal $output [[1, two, 3]]

    let code = { print [1, "two", 3] [4, "five", 6] }
    let output = $in | run $code
    assert equal $output [[1, two, 3], [4, five, 6]]
}

# [test]
def records [] {
    let code = { print {} }
    let output = $in | run $code
    assert equal $output [{}]

    let code = { print { a: 1, b: "two" } }
    let output = $in | run $code
    assert equal $output [{a: 1, b: two}]

    let code = { print { a: 1, b: "two" } { c: 3, d: "four" } }
    let output = $in | run $code
    assert equal $output [{a: 1, b: "two"}, {c: 3, d: "four"}]
}

# [test]
def tables [] {
    let code = { print ([[a, b, c]; [1, 2, 3]] | take 0) }
    let output = $in | run $code
    assert equal $output [[]]

    let code = { print [[a, b, c]; [1, "two", 3], [4, "five", 6]] }
    let output = $in | run $code
    assert equal $output [ [{a: 1, b: two, c: 3}, {a: 4, b: five, c: 6}] ]

    let code = { print [[a, b, c]; [1, "two", 3]] [[d, e, f]; [4, "five", 6]] }
    let output = $in | run $code
    assert equal $output [ [{a: 1, b: two, c: 3}], [{d: 4, e: five, f: 6}] ]
}

# [test]
def table_in_record [] {
    let code = { print { a: 1, b: [[c, d]; [1, 2]] } }
    let output = $in | run $code
    assert equal $output [{a: 1, b: [{c: 1, d: 2}]}]
}

# [test]
def record_in_table [] {
    let code = { print [[a, b]; [1, {c: 2, d: 3}]] }
    let output = $in | run $code
    assert equal $output [ [[a, b]; [1, {c: 2, d: 3}]] ]
}

def run [code: closure]: record -> string {
    let result = $in | harness run $code
    assert equal $result.result "PASS"
    $result.output
        | each { |row| $row.items } # Unpack from stream record
}
