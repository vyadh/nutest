
# This module is for running tests.
#
# Example Usage:
#   use nutest; nutest run-tests

# Discover annotated test commands.
export def list-tests [
    --path: string # Location of tests (defaults to current directory)
]: nothing -> table<suite: string, test: string> {

    use discover.nu

    let path = $path | default $env.PWD | check-path
    let suites = $path | discover suite-files | discover test-suites

    $suites | each { |suite|
        $suite.tests
            | where { $in.type in ["test", "ignore"] }
            | each { |test| { suite: $suite.name, test: $test.name } }
    } | flatten | sort-by suite test
}

# todo thread panic on below options?
use completions.nu *

# Discover and run annotated test commands.
export def run-tests [
    --path: path           # Location of tests (defaults to current directory)
    --match-suites: string@"nu-complete suites"  # Regular expression to match against suite names (defaults to all)
    --match-tests: string@"nu-complete tests"    # Regular expression to match against test names (defaults to all)
    --strategy: record     # Overrides test run behaviour, such as test concurrency (defaults to automatic)
    --display: string@"nu-complete display"      # Display during test run (defaults to terminal, or none if result specified)
    --returns: string@"nu-complete returns" = "nothing" # Results to return in a pipeline (defaults to nothing)
    --report: record<type: string, path: string> # Save a test report to file, e.g. `{ type: "junit", path: "report.xml" }`
    --fail                 # Print results and exit with non-zero status if any tests fail (useful for CI/CD systems)
]: nothing -> any {

    use discover.nu
    use orchestrator.nu
    use store.nu

    let path = $path | default $env.PWD | check-path
    let suite = $match_suites | default ".*"
    let test = $match_tests | default ".*"
    let strategy = $strategy | select-strategy
    let display = $display | select-display $returns
    let returns = $returns | select-returns
    let report = $report | select-report

    # Discovered suites are of the type:
    # list<record<name: string, path: string, tests<table<name: string, type: string>>>

    let test_suites = $path
        | discover suite-files --matcher $suite
        | discover test-suites --matcher $test

    store create

    do $display.run-start
    $test_suites | (orchestrator run-suites $display $strategy)
    do $display.run-complete

    let result = do $returns.results
    let success = store success
    try { do $report.save $result } catch { |error| print -e $error }

    store delete

    # To reflect the exit code we need to print the results instead
    if ($fail and not $success) {
        print $result
        exit 1
    } else {
        $result
    }
}

def check-path []: string -> string {
    let path = $in
    if (not ($path | path exists)) {
        error make { msg: $"Path doesn't exist: ($path)" }
    }
    $path
}

def select-strategy []: any -> record<threads: int> {
    let strategy = $in | default { }
    let default = {
        # Rather than using `sys cpu` (an expensive operation), platform-specific
        # mechanisms, or complicating the code with different invocations of par-each,
        # we can leverage that Rayon's default behaviour can be activated by setting
        # the number of threads to 0. See [ThreadPoolBuilder.num_threads](https://docs.rs/rayon/latest/rayon/struct.ThreadPoolBuilder.html#method.num_threads).
        # This is also what the par-each implementation does.
        threads: 0
    }
    $default | merge $strategy
}

# A display implements the event processor interface of the orchestrator
def select-display [
    returns_option: any
]: any -> record<name: string, run-start: closure, run-complete: closure, test-start: closure, test-complete: closure> {

    let display_option = $in
    let display_option = match $display_option {
        null if $returns_option != null and $returns_option != "nothing" => "nothing"
        null => "terminal"
        _ => $display_option
    }

    match $display_option {
        "nothing" => {
            use display/display_nothing.nu
            display_nothing create
        }
        "terminal" => {
            use display/display_terminal.nu
            display_terminal create
        }
        "table" => {
            use display/display_table.nu
            display_table create
        }
        _ => {
            error make { msg: $"Unknown display: ($display_option)" }
        }
    }
}

# The `returns` provides data to downstream pipeline steps
def select-returns []: any -> record<name: string, result: closure> {
    let returns_option = $in

    match $returns_option {
        "nothing" => {
            use returns/returns_nothing.nu
            returns_nothing create
        }
        "summary" => {
            use returns/returns_summary.nu
            returns_summary create
        }
        "table" => {
            use returns/returns_table.nu
            returns_table create
        }
        _ => {
            error make { msg: $"Unknown return: ($returns_option)" }
        }
    }
}

def select-report []: any -> record<save: closure> {
    let report_option = $in

    match $report_option {
        null => {
            use report/report_nothing.nu
            report_nothing create
        }
        { type: "junit", path: $path } => {
            use report/report_junit.nu
            report_junit create $path
        }
        _ => {
            error make { msg: $"Unknown report: ($report_option)" }
        }
    }
}
