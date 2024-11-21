use discover.nu
use orchestrator.nu
use db.nu

# nu -c "use std/testing; (testing .)"

export def main [
    --path: path
    --suite: string
    --test: string
] {
    # todo error messages are bad when these are misconfgured
    let path = $path | default $env.PWD
    let suite = $suite | default ".*"
    let test = $test | default ".*"

    # Discovered suites are of the type:
    # list<record<name: string, path: string, tests<table<name: string, type: string>>>

    let suites = discover list-test-suites $path
    let filtered = $suites | filter-tests $suite $test
    db create
    let results = orchestrator run-suites $filtered
    db delete

    $results
}

def filter-tests [
    suite: string, test: string
]: table<name: string, path: string, tests<table<name: string, type: string>>> -> table<name: string, path: string, tests<table<name: string, type: string>>> {
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
