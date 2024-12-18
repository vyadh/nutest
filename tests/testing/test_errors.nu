use std/assert
use ../../std/testing/orchestrator.nu
use ../../std/testing/reporter_table.nu
use ../../std/testing/theme.nu

# [strategy]
# Database is global so we need to run tests sequentially.
def sequential []: nothing -> record {
    { threads: 1 }
}

# [before-all]
def reporter-setup []: nothing -> record {
    let reporter = reporter_table create (theme none)
    do $reporter.start
    { reporter: $reporter }
}

# [after-all]
def reporter-complete [] {
    let reporter = $in.reporter
    do $reporter.complete
}

# [before-each]
def setup-temp-dir []: nothing -> record {
    let temp = mktemp --tmpdir --directory
    { temp: $temp }
}

# [after-each]
def cleanup-temp-dir [] {
    let context = $in
    rm --recursive $context.temp
}

# [test]
def assertion-failure [] {
    let test = "assert equal 1 2"

    let output = $in | test-run $test

    assert equal ($output | trim-all) ("
        Assertion failed.
        These are not equal.
        |>Left  : '1'
        |>Right : '2'
    " | trim-all)
}

# [test]
def basic-error [] {
    let test = "error make { msg: 'some error' }"

    let output = $in | test-run $test

    assert equal $output "some error"
}

def test-run [code: string]: record -> string {
    let context = $in
    let temp = $context.temp

    let test = random chars
    let suite = $code | create-suite $temp $test
    let reporter = $context.reporter

    [$suite] | orchestrator run-suites $reporter { threads: 1 }
    let results = do $reporter.results
    let result = $results | where test == $test | first

    assert equal $result.result "FAIL"

    $result.output
}

def create-suite [temp: string, test: string]: string -> record {
    let path = $temp | path join $"suite.nu"

    $"
        use std/assert
        def ($test) [] {
            ($in)
        }
    " | save --append $path

    {
        name: "suite"
        path: $path
        tests: [{ name: $test, type: "test" }]
    }
}

def trim-all []: string -> string {
    $in | str trim | str replace --all --regex '[\n\t ]+' ' '
}
