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

    print -e "|>"
    #print ($suites | describe)
    print -e ($suites | table --expand)
    print -e "/|>"

    #table<name: string, results: table<name: string, result: bool, output: string, error: record<msg: string, debug: string>>
    let results = runner run-suites $suites
    #print "====================>"
    #print ($results | describe)
    #print ($results | table --expand)
    #print "<===================="

    let tests = $results
        | where ($it.results != null)
        | each { |result| $result.results | insert suite $result.name }
        | flatten
        | select suite name success output error

    print ($tests | table --expand)

}
