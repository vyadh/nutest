module discover.nu
module orchestrator.nu

# nu -c "use std/testing; (testing .)"

export def main [path: string = "."] {
    use discover
    use orchestrator

    #list<record<name: string, path: string, tests<table<name: string, type: string>>>
    let suites = discover list-test-suites $path
    let results = orchestrator run-suites $suites
    let tests = $results

    $tests
}
