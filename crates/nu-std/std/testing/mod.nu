module discover.nu
module runner.nu

#export use std/testing/discover.du [
#export use ./discover.nu [
#    list-files
#    list-tests
#]

#export use runner.nu [
#    run-suites
#]
#    use runner [ run-suites ]
#module runner { export run-suites }

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

    print ($tests | table --expand)

}
