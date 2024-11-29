use discover.nu
use orchestrator.nu
use reporter_table.nu
use color_scheme.nu

# nu -c "use std/test; (test .)"

export def main [
    --path: path
    --match-suites: string
    --match-tests: string
    --threads: int
    --no-color
    --fail
] {
    # TODO error messages are bad when these are misconfigured
    let path = $path | default $env.PWD
    let suite = $match_suites | default ".*"
    let test = $match_tests | default ".*"
    let threads = $threads | default (default-threads)

    # Discovered suites are of the type:
    # list<record<name: string, path: string, tests<table<name: string, type: string>>>

    let suites = discover list-test-suites $path
    let filtered = $suites | filter-tests $suite $test

    let reporter = reporter_table create (color_scheme create $no_color)
    do $reporter.start
    $filtered | orchestrator run-suites $reporter $threads
    let results = do $reporter.results
    let failure = $results | where result =~ FAIL | is-not-empty
    do $reporter.complete

    # To reflect the exit code we need to print the results instead
    if ($fail) {
        print $results
        exit (if $failure { 1 } else { 0 })
    } else {
        $results
    }
}

def default-threads []: nothing -> int {
    # Rather than using `sys cpu` (an expensive operation), platform-specific
    # mechanisms, or complicating the code with different invocations of par-each,
    # we can leverage that Rayon's default behaviour can be activated by setting
    # the number of threads to 0. See [ThreadPoolBuilder.num_threads](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html#method.num_threads).
    # This is also what the par-each implementation does.
    0
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
