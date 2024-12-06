use std/assert
source ../../std/test/store.nu

# [before-all]
def create_store [] record -> record {
    create
    { }
}

# [after-all]
def delete_store [] {
    delete
}

# [before-each]
def create-state-file [] record -> record {
    let state_file = mktemp
    { state_file: $state_file }
}

# [after-each]
def delete-state-file [] record -> nothing {
    let state_file = $in.state_file
    rm -f $state_file
}

def initialise-attempts-file [] record<state: string> -> nothing {
    let context = $in
    "0" | save -f $context.state_file
}

def new-attempt [] record<state: string> -> nothing {
    let context = $in
    ($context | attempt-count) + 1 | save -f $context.state_file
}

def attempt-count [] record<state: string> -> int {
    let context = $in
    (open $context.state_file | into int)
}

# [test]
def retry-on-table-lock-fails [] {
    let context = $in
    $context | initialise-attempts-file
    let table = "test_table"

    let operation = {
        $context | new-attempt
        throw-database-locked-error $table
    }

    try {
        retry-on-lock $table $operation
        assert false # Should not reach here
    } catch { |e|
        let result = ($e.json | from json).msg
        assert str contains $result $"Failed to insert into ($table) after"
    }
    assert equal ($context | attempt-count) 20
}

# [test]
def retry-on-table-lock-eventually-succeeds [] {
    let context = $in
    $context | initialise-attempts-file
    let table = "test_table"

    let operation = {
        $context | new-attempt
        if ($context | attempt-count) < 5 {
            throw-database-locked-error $table
        }
    }

    try {
        retry-on-lock $table $operation
    } catch { |e|
        assert false # Should not reach here
    }
    assert equal ($context | attempt-count) 5
}

# [test]
def retry-on-table-lock-throws-other-errors [] {
    let context = $in
    $context | initialise-attempts-file
    let table = "test_table"

    let operation = {
        $context | new-attempt
        error make { msg: "some other error" }
    }

    try {
        retry-on-lock $table $operation
        assert false # Should not reach here
    } catch { |e|
        let result = ($e.json | from json).msg
        assert equal $result "some other error"
    }
    assert equal ($context | attempt-count) 1
}

def throw-database-locked-error [table: string] {
    error make {
        msg: "database error"
        label: {
            text: $"database table is locked: ($table)"
        }
    }
}
