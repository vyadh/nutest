use discover.nu

export def "nu-complete display" []: nothing -> record<options: record, completions: table<value: string, description: string>> {
    {
        options: {
            sort: false
        }
        completions: [
            [value description];
            [
                "none" # rename nothing
                "No display output during test run (default when returning a result)."
            ]
            [
                "terminal"
                "Output test results as they complete (default when returning nothing)."
            ]
            [
                "table"
                "A table listing all tests with decorations and color."
            ]
        ]
    }
}

export def "nu-complete returns" []: nothing -> record<options: record, completions: table<value: string, description: string>> {
    {
        options: {
            sort: false
        }
        completions: [
            [value description];
            [
                "nothing"
                "Returns no results from the test run."
            ]
            [
                "table"
                "Returns a table listing all test results."
            ]
            [
                "summary"
                "Returns a summary of the test results."
            ]
        ]
    }
}

export def "nu-complete suites" [context: string]: nothing -> record {
    let options = $context | parse-command-context
    let suites = $options.path
        | discover suite-files --matcher $options.suite
        | each { path parse | get stem }
        | sort

    {
        options: {
            completion_algorithm: "prefix"
            positional: false # Use substring matching
        }
        completions: $suites
    }
}

export def "nu-complete tests" [context: string]: nothing -> record {
    let options = $context | parse-command-context

    let tests = $options.path
        | discover suite-files --matcher $options.suite
        | discover test-suites --matcher $options.test
        | each { |suite| $suite.tests | where { $in.type in ["test", "ignore"] } }
        | flatten
        | sort
        | each {
            if ($in.name | str contains " ") {
                $'"($in.name)"'
            } else {
                $in.name
            }
        }

    {
        options: {
            completion_algorithm: "prefix"
            positional: false # Use substring matching
        }
        completions: $tests
    }
}

def parse-command-context []: string -> record<suite: string, test: string, path: string> {
    let options = (
        $in
            # Strip everything before the actual arguments
            | str replace --regex '^.*?--' '--'
            # Group into parameter name and value pairs, being: table<name, value>
            | parse --regex '--(?P<name>[-\w]+)\s+(?P<value>[^--]+)'
            # Extract into a table that can be converted into a record of "name: value" pairs
            | each { |pair| [ ($pair | get name), ($pair | get value | str trim) ] }
            | into record
    )

    {
        suite: ($options | get-or-null "match-suites" | default ".*")
        test: ($options | get-or-null "match-tests" | default ".*")
        path: ($options | get-or-null "path" | default ".")
    }
}

# A slight variation on get, which also translates empty strings to null
def get-or-null [name: string]: record -> string {
    let value = $in | get --optional $name
    if ($value | is-empty) {
        null
    } else {
        $value
    }
}
