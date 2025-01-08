
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
    #todo we can now more easily allow matchers here
    let suites = $path | discover suite-files | discover test-suites

    $suites | each { |suite|
        $suite.tests
            | where { $in.type in ["test", "ignore"] }
            | each { |test| { suite: $suite.name, test: $test.name } }
    } | flatten | sort-by suite test
}

use completions.nu *

# Discover and run annotated test commands.
export def run-tests [
    --path: path           # Location of tests (defaults to current directory)
    --match-suites: string@"nu-complete suites" # Regular expression to match against suite names (defaults to all)
    --match-tests: string@"nu-complete tests"   # Regular expression to match against test names (defaults to all)
    --strategy: record     # Override test run behaviour, such as test concurrency (defaults to automatic)
    --reporter: string@"nu-complete reporter" = "terminal" # The reporter used for test result output
    --formatter: string@"nu-complete formatter" # A formatter for output messages (defaults to reporter-specific)
    --fail                 # Print results and exit with non-zero status if any tests fail (useful for CI/CD systems)
]: nothing -> any {

    use discover.nu
    use orchestrator.nu
    use store.nu

    let path = $path | default $env.PWD | check-path
    let suite = $match_suites | default ".*"
    let test = $match_tests | default ".*"
    let strategy = (default-strategy $reporter) | merge ($strategy | default { })
    let formatter = $formatter | default null
    let reporter = select-reporter $reporter $formatter

    # Discovered suites are of the type:
    # list<record<name: string, path: string, tests<table<name: string, type: string>>>

    let test_suites = $path
        | discover suite-files --matcher $suite
        | discover test-suites --matcher $test

    store create
    do $reporter.start
    $test_suites | (orchestrator run-suites $reporter $strategy)
    let results = do $reporter.results
    do $reporter.complete
    let success = store success
    store delete

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

def default-strategy [reporter: string]: nothing -> record<threads: int> {
    {
        # Rather than using `sys cpu` (an expensive operation), platform-specific
        # mechanisms, or complicating the code with different invocations of par-each,
        # we can leverage that Rayon's default behaviour can be activated by setting
        # the number of threads to 0. See [ThreadPoolBuilder.num_threads](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html#method.num_threads).
        # This is also what the par-each implementation does.
        threads: 0

        # Normal rendered errors have useful information for terminal mode,
        # but don't fit well for table-based reporters
        error_format: (if $reporter == "terminal" { "rendered" } else { "compact" })
    }
}

def check-path []: string -> string {
    let path = $in
    if (not ($path | path exists)) {
        error make { msg: $"Path doesn't exist: ($path)" }
    }
    $path
}

def select-reporter [
    reporter_option: string
    formatter_option?: string
]: nothing -> record<start: closure, complete: closure, success: closure, results: closure, 'fire-result': closure, 'fire-output': closure> {

    match $reporter_option {
        "table-pretty" => {
            use theme.nu
            use reporter_table.nu

            let theme = theme standard
            let error_format = "compact"
            let formatter = $formatter_option | default "pretty" | select-formatter $theme $error_format

            reporter_table create $theme $formatter
        }
        "table" => {
            use theme.nu
            use reporter_table.nu

            let theme = theme none
            let formatter = $formatter_option | default "unformatted" | select-formatter $theme

            reporter_table create $theme $formatter
        }
        "summary" => {
            use reporter_summary.nu

            reporter_summary create
        }
        "terminal" => {
            use theme.nu
            use reporter_terminal.nu

            let theme = theme standard
            let error_format = "rendered"
            let formatter = $formatter_option | default "pretty" | select-formatter $theme $error_format

            reporter_terminal create $theme $formatter
        }
        "junit" => {
            use theme.nu
            use reporter_junit.nu

            # todo Formatter and/or theme would need to remove ansi styling
            let theme = theme none
            let formatter = $formatter_option | default "unformatted" | select-formatter $theme

            reporter_junit create $formatter
        }
        _ => {
            error make { msg: $"Unknown reporter: ($reporter_option)" }
        }
    }
}

def select-formatter [theme: closure, error_format: string = "record"]: string -> closure {
    use formatter.nu

    let option = $in
    match $option {
        "preserved" => (formatter preserved)
        "unformatted" => (formatter unformatted)
        "pretty" => (formatter pretty $theme $error_format)
        _ => {
            error make { msg: $"Unknown formatter: ($option)" }
        }
    }
}
