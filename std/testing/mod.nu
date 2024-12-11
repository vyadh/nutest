# This module is for running tests.
#
# Example Usage:
#   use std/testing *; run-tests

# Discover annotated test commands.
export def list-tests [
    --path: string # Location of tests (defaults to current directory)
]: nothing -> table<suite: string, test: string> {

    use discover.nu

    let path = $path | default $env.PWD | check-path
    let suites = discover list-test-suites $path

    $suites | each { |suite|
        $suite.tests
            | where { $in.type in ["test", "ignore"] }
            | each { |test| { suite: $suite.name, test: $test.name } }
    } | flatten | sort-by suite test
}

# Discover and run annotated test commands.
#
# The results are returned based on the specified reporter, being one of:
# - `decorated` (default): A table listing all tests with decorations and color.
# - `table`: A table listing all test results without decorations/colour, useful for querying.
# - `summary`: A table with the total tests passed/failed/skipped.
export def run-tests [
    --path: path           # Location of tests (defaults to current directory)
    --match-suites: string # Regular expression to match against suite names (defaults to all)
    --match-tests: string  # Regular expression to match against test names (defaults to all)
    --threads: int         # Number of threads used to run tests (defaults to automatic (zero))
    --reporter: string     # The reporter used for test result output
    --fail                 # Print results and exit with non-zero status if any tests fail (useful for CI/CD systems)
]: nothing -> any {

    use discover.nu
    use orchestrator.nu

    let path = $path | default $env.PWD | check-path
    let suite = $match_suites | default ".*"
    let test = $match_tests | default ".*"
    let threads = $threads | default (default-threads)
    let reporter = select-reporter ($reporter | default "decorated")

    # Discovered suites are of the type:
    # list<record<name: string, path: string, tests<table<name: string, type: string>>>

    let suites = discover list-test-suites $path
    let filtered = $suites | filter-tests $suite $test

    do $reporter.start
    $filtered | orchestrator run-suites $reporter $threads
    let results = do $reporter.results
    let success = do $reporter.success
    do $reporter.complete

    # To reflect the exit code we need to print the results instead
    if ($fail) {
        print $results
        exit (if $success { 0 } else { 1 })
    } else if ($reporter.has-return-value) {
        $results
    } else {
        # Nothing to print
        null
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

def check-path []: string -> string {
    let path = $in
    if (not ($path | path exists)) {
        error make { msg: $"Path doesn't exist: ($path)" }
    }
    $path
}

def select-reporter [reporter: string]: nothing -> record<start: closure, complete: closure, success: closure, results: closure, fire-result: closure, fire-output: closure> {
    match $reporter {
        "decorated" => {
            use theme.nu
            use reporter_table.nu

            reporter_table create (theme standard)
        }
        "table" => {
            use theme.nu
            use reporter_table.nu

            reporter_table create (theme none)
        }
        "summary" => {
            use reporter_summary.nu

            reporter_summary create
        }
        "terminal" => {
            use theme.nu
            use reporter_terminal.nu

            reporter_terminal create (theme standard)
        }
        _ => {
            error make { msg: $"Unknown reporter: ($reporter)" }
        }
    }
}
