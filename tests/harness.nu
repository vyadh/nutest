use ../nutest/orchestrator.nu
use ../nutest/returns/returns_table.nu
use ../nutest/theme.nu
use ../nutest/formatter.nu
use ../nutest/store.nu

# A harness for running tests against nutest itself.

# Encapsulate before-all behaviour
export def setup-tests []: record -> record {
    store create
    $in
}

# Encapsulate after-all behaviour
export def cleanup-tests []: record -> nothing {
    store delete
}

# Encapsulate before-each behaviour
export def setup-test []: record -> record {
    $in | merge {
        temp_dir: (mktemp --tmpdir --directory)
    }
}

# Encapsulate after-each behaviour
export def cleanup-test []: record -> nothing {
    if $in.temp_dir? != null {
        rm --recursive $in.temp_dir
    }
}

export def run [
    code: closure
    strategy: record = { }
]: record<temp_dir: string> -> record<result: string, output: any> {

    let context = $in
    let temp = $context.temp_dir
    let returns = returns_table create
    let strategy = { threads: 1 } | merge $strategy

    let test = random chars
    let suite = $code | create-closure-suite $temp $test
    [$suite] | orchestrator run-suites (noop-event-processor) $strategy
    let results = do $returns.results

    let result = $results | where test == $test
    if ($result | is-empty) {
        error make { msg: $"No results found for test: ($test)" }
    } else {
        $result | first
    }
}

def noop-event-processor []: nothing -> record<run-start: closure, run-complete: closure, test-start: closure, test-complete: closure> {
    {
        run-start: { || ignore }
        run-complete: { || ignore }
        test-start: { |row| ignore }
        test-complete: { |row| ignore }
    }
}

def create-closure-suite [temp: string, test: string]: closure -> record {
    let path = $temp | path join $"suite.nu"
    let code = view source $in

    $"
        use std/assert
        use std/testing *

        def ($test) [] {
            do ($code)
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
