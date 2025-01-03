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
    use discover.nu

    # todo use a regex match to narrow the suites using 'like'
    # todo might be worth moving filtering to discovery to help share logic
    # todo and split filtering of suites and tests into separate functions

    # todo need to process command line arguments to pick up the arguments:
    # --match-suites (anything specified)
    # --path (to use with list-files)

    # todo we should also use this --match-suites to filter the tests doing completion for --match-tests

    let options = $context | parse-command-context

    let suites = discover list-files $options.path
        | each { path parse | get stem }

    let suites = discover list-files $options.path
        | each { path parse | get stem }
        | where ($it like $options.suite)

    {
        options: {
            completion_algorithm: "prefix"
            positional: false # Use substring matching
        }
        completions: $suites
    }
}

def parse-command-context []: string -> record<suite: string, test: string, path: string> {
    let options = $in
        | split row --regex " +"
        | skip while { not ($in | str starts-with "--") }
        | window 2 --stride 2
        | into record

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
