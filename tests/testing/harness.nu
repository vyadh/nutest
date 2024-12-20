# A harness for running tests against nutest itself.

use ../../std/testing/orchestrator.nu
use ../../std/testing/reporter_table.nu
use ../../std/testing/theme.nu

export def start-tests []: nothing -> record {
    let reporter = reporter_table create (theme none)
    do $reporter.start
    $in | merge {
        reporter: $reporter
    }
}

export def tests-complete []: record<reporter: record> -> nothing {
    let reporter = $in.reporter
    do $reporter.complete
}

export def with-temp-dir []: record -> record {
    $in | merge {
        reporter: $in.reporter
        temp_dir: (mktemp --tmpdir --directory)
    }
}

export def cleanup-test []: record -> nothing {
    if $in.temp_dir? != null {
        rm --recursive $in.temp_dir
    }
}

export def run-code [
    code: string
    strategy: record = { }
]: record<reporter: record, temp_dir: string> -> record<result: string, output: string> {

    let context = $in
    let temp = $context.temp_dir
    let reporter = $context.reporter
    let strategy = { threads: 1, error_format: "compact" } | merge $strategy

    let test = random chars
    let suite = $code | create-suite $temp $test
    [$suite] | orchestrator run-suites $reporter $strategy
    let results = do $reporter.results
    let result = $results | where test == $test | first

    $result
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
