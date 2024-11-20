module discover.nu
module orchestrator.nu

# nu -c "use std/testing; (testing .)"

export def main [
    --path: path
    --suite: string
    --test: string
] {
    use discover
    use orchestrator

    let path = $path | default $env.PWD
    let suite = $suite | default ".*"
    let test = $test | default ".*"

    # Discovered suites are of the type:
    # list<record<name: string, path: string, tests<table<name: string, type: string>>>

    let suites = discover list-test-suites $path
    let filtered = $suites | filter-tests $suite $test
    let results = orchestrator run-suites $filtered
    let tests = $results

    $tests
}

def filter-tests [suite: string, test: string] -> table {
    ($in
        | where name =~ $suite
        | each { |suite|
            {
                name: $suite.name
                path: $suite.path
                tests: ($suite.tests | where type != test or name =~ $test)
            }
        }
        | where ($it.tests | is-not-empty)
    )
}
