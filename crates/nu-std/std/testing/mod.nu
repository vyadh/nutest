module discover.nu
module runner.nu

# nu -c "use std/testing; (testing .)"

export def main [path: string = "."] {
    use discover
    use runner

    #list<record<name: string, path: string, tests<table<name: string, type: string>>>
    let suites = discover list-test-suites $path
    let results = runner run-suites $suites
    let tests = $results
        | where ($it.results != null)
        | each { |result| $result.results | insert suite $result.name }
        | flatten
        | select suite name success output error

    $tests
}
