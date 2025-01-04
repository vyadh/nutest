use discover.nu

export def "nu-complete reporter" []: nothing -> record<options: record, completions: table<value: string, description: string>> {
    {
        options: {
            sort: false
        }
        completions: [
            [value description];
            [
                "terminal"
                "Output test results as they complete as text. (default)"
            ]
            [
                "table-pretty"
                "A table listing all tests with decorations and color."
            ]
            [
                "table"
                "A table listing all test results as data, useful for querying."
            ]
            [
                "summary"
                "A table with the total tests passed/failed/skipped."
            ]
        ]
    }
}

export def "nu-complete formatter" []: nothing -> record<options: record, completions: table<value: string, description: string>> {
    {
        options: {
            sort: false
        }
        completions: [
            [value description];
            [
                "preserved"
                "Output full output information including stream metadata."
            ]
            [
                "unformatted"
                "Show the original data output with original typing, each item in a list."
            ]
            [
                "pretty"
                "Format all output as text, with `stderr` text highlighted and errors in their rendered form."
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
        ast --flatten $in
            # Allow consuming until the first "internal call"
            | reverse
            | take while { $in.shape != "shape_internalcall" }
            | reverse
            # Group into parameter name and value pairs
            | window 2 --stride 2
            # Extract into a record of "name: value" pairs (assumes name then value)
            | each { |pair| $pair | get content }
            | into record
    )

    {
        suite: ($options | get-or-null "--match-suites" | default ".*")
        test: ($options | get-or-null "--match-tests" | default ".*")
        path: ($options | get-or-null "--path" | default ".")
    }
}

# A slight variation on get, which also translates empty strings to null
def get-or-null [name: string]: record -> string {
    let value = $in | get --ignore-errors $name
    if ($value | is-empty) {
        null
    } else {
        $value
    }
}
