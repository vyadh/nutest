use std/assert

const default_pattern = '**/{*[\-_]test,test[\-_]*}.nu'

export def suite-files [
    --glob: string = $default_pattern
    --matcher: string = ".*"
]: string -> list<string> {

    let path = $in
    $path
        | list-files $glob
        | where ($it | path parse | get stem) =~ $matcher
}

def list-files [ pattern: string ]: string -> list<string> {
    let path = $in
    if ($path | path type) == file {
        [$path]
    } else {
        cd $path
        glob $pattern
    }
}

export def test-suites [
    --matcher: string = ".*"
]: list<string> -> table<name: string, path: string, tests:table<name: string, type: string>> {

    let suite_files = $in
    let result = $suite_files
        | par-each { discover-suite $in }
        | filter-tests $matcher

    # The following manifests the data to avoid laziness causing errors to be thrown in the wrong context
    # Some parser errors might be a `list<error>`, collecting will cause it to be thrown here
    $result | collect
    # Others are only apparent collecting the tests table
    $result | each { |suite| $suite.tests | collect }

    $result
}

def discover-suite [test_file: string]: nothing -> record<name: string, path: string, tests: table<name: string, type: string>> {
    let query = test-query $test_file
    let result = (^$nu.current-exe --no-config-file --commands $query)
        | complete

    if $result.exit_code == 0 {
        parse-suite $test_file ($result.stdout | from nuon)
    } else {
        error make { msg: $result.stderr }
    }
}

# Query any method with a specific tag in the description
def test-query [file: string]: nothing -> string {
    let query = "
        scope commands
            | where ( $it.type == 'custom' and $it.description =~ '\\[[a-z-]+\\]' )
            | each { |item| {
                name: $item.name
                description: $item.description
            } }
            | to nuon
    "
    $"source ($file); ($query)"
}

def parse-suite [test_file: string, tests: list<record<name: string, description: string>>]: nothing -> record<name: string, path: string, tests: table<name: string, type: string>> {
    {
        name: ($test_file | path parse | get stem)
        path: $test_file
        tests: ($tests | each { parse-test $in })
    }
}

def parse-test [test: record<name: string, description: string>]: nothing -> record<name: string, type: string> {
    let type = $test.description
        | parse --regex '.*\[([a-z-]+)\].*'
        | get capture0
        | first

    {
        name: $test.name,
        type: $type
    }
}

def filter-tests [
    matcher: string
]: table<name: string, path: string, tests:table<name: string, type: string>> -> table<name: string, path: string, tests: table<name: string, type: string>> {

    let tests = $in
    $tests
        | each { |suite|
            {
                name: $suite.name
                path: $suite.path
                tests: ($suite.tests | where
                    # Filter only 'test' and 'ignore' by pattern
                    ($it.type != "test" and $it.type != "ignore") or $it.name =~ $matcher
                )
            }
        }
        # Remove suites that have no actual tests to run
        | where ($it.tests | where type in ["test", "ignore"] | is-not-empty)
}
