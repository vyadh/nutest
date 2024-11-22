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

def filter-tests [
    suite_pattern: string, test_pattern: string
]: table<name: string, path: string, tests<table<name: string, type: string>>> -> table<name: string, path: string, tests<table<name: string, type: string>>> {
    ($in
        | where name =~ $suite_pattern
        | each { |suite|
            {
                name: $suite.name
                path: $suite.path
                tests: ($suite.tests | where
                    # Filter only 'test' and 'ignore' by pattern
                    ($it.type != test and $it.type != ignore) or $it.name =~ $test_pattern
                )
            }
        }
        | where ($it.tests | is-not-empty)
    )
}
