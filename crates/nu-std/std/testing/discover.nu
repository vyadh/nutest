use ../../std/assert

#const default_pattern = "**/{*_test,test_*}.nu"
const default_pattern = "**/*.nu"

# Usage:
#  cd crates/nu-std
#  nu -c 'use std/testing; testing list-files .'

# Test commands?
# test all
# test file <file>
# test path <path>

# Work todo
# - Error handling of delegated nu commands and exit codes and visibility of what went wrong incl syntax errors
# - filter unknown types before they hit runner
# - Logging of process

export def list-files [
    path: string
    pattern: string = $default_pattern
] -> list<string> {

    cd $path
    glob $pattern
}

export def list-test-suites [path: string] -> table<name: string, path: string, tests<table<name: string, type: string>> {
    list-files $path $default_pattern
        | each { discover-suite $in }
}

def discover-suite [test_file: string] -> record<name: string, path: string, tests: table<name: string, type: string>> {
    let query = test-query $test_file
    let result = (^$nu.current-exe --no-config-file --commands $query)
        | complete

    if $result.exit_code == 0 {
        parse-suite $test_file ($result.stdout | from nuon)
    } else {
        error make { msg: $result.stderr }
    }
}

def parse-suite [test_file: string, tests: list<record<name: string, description: string>>] -> record<name: string, path: string, tests: table<name: string, type: string>> {
    {
        name: ($test_file | path parse | get stem)
        path: $test_file
        tests: ($tests | each { parse-test $in })
    }
}

def parse-test [test: record<name: string, description: string>] -> record<name: string, type: string> {
    let type = $test.description
        | parse --regex '.*\[([a-z]+)\].*'
        | get capture0
        | first

    {
        name: $test.name,
        type: $type
    }
}

# Query any method with a specific tag in the description
def test-query [file: string] -> string {
    let query = "
        scope commands
            | where ( $it.type == 'custom' and $it.description =~ '\\[[a-z]+\\]' )
            | each { |test| {
                name: $test.name
                description: $test.description
            } }
            | to nuon
    "
    $"source ($file); ($query)"
}
