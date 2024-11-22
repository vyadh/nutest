use discover.nu
use orchestrator.nu
use db.nu
use reporter_table.nu

# nu -c "use std/testing; (testing .)"

export def main [
    --path: path
    --suite: string
    --test: string
    --no-color
] {
    # todo error messages are bad when these are misconfgured
    let path = $path | default $env.PWD
    let suite = $suite | default ".*"
    let test = $test | default ".*"
    let color = not $no_color

    # Discovered suites are of the type:
    # list<record<name: string, path: string, tests<table<name: string, type: string>>>

    let suites = discover list-test-suites $path
    let filtered = $suites | filter-tests $suite $test

    let reporter = reporter_table create $color
    do $reporter.start
    $filtered | orchestrator run-suites $reporter
    let results = do $reporter.results
    do $reporter.complete

    $results
}

# TODO also filter ignored
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
