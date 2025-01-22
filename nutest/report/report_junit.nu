use ../store.nu

# JUnit XML format.
# https://llg.cubic.org/docs/junit
# Example:
#  <testsuites name="s" disabled="n" tests="n" failures="n" errors="n" time="d">
#    <testsuite name="s" disabled="n" tests="n" failures="n" errors="n" time="d" timestamp="">
#       <testcase name="s" classname="s" time="d" status="s">
#           <skipped message=""/>
#           <error message="" type=""></error>
#           <failure message="" type=""></failure>
#           <system-out></system-out>
#           <system-err></system-err>
#       </testcase>
#       <system-out></system-out>
#       <system-err></system-err>
#    </testsuite>
#  </testsuites>

export def create [path: string]: nothing -> record<name: string, save: closure, results: closure> {
    {
        name: "report junit"
        results: { create-report }
        save: { create-report | save $path }
    }
}

def create-report []: nothing -> string {
    query-results | collect | to junit
}

def query-results []: nothing -> table<suite: string, test: string, result: string, output: list<any>> {
    store query | each { |row|
        {
            suite: $row.suite
            test: $row.test
            result: $row.result
            output: $row.output
        }
    }
}

export def "to junit" []: table<suite: string, test: string, result: string, output: list<any>> -> string {
    $in | testsuites | to xml --self-closed --indent 2
}

# <testsuites name="s" disabled="n" tests="n" failures="n" errors="n" time="d">
def testsuites []: table<suite: string, test: string, result: string, output: list<any>> -> record {
    let rows = $in
    let stats = $rows | count
    {
        tag: "testsuites"
        attributes: {
            name: "nutest"
            tests: $"($stats.total)"
            disabled: $"($stats.skipped)"
            failures: $"($stats.failed)"
        }
        content: (
            $rows
                | group-by suite
                | items { |_, suite_results|
                    $suite_results | testsuite
                }
        )
    }
}

# <testsuite name="s" disabled="n" tests="n" failures="n" errors="n" time="d" timestamp="">
def testsuite []: table<suite: string, test: string, result: string, output: list<any>> -> record {
    let rows = $in
    if ($rows | is-empty) {
        error make { msg: "No test entries" }
    }

    let suite = $rows | first | get suite
    let stats = $rows | count
    {
        tag: "testsuite"
        attributes: {
            name: $suite
            tests: $"($stats.total)"
            disabled: $"($stats.skipped)"
            failures: $"($stats.failed)"
        }
        content: ($rows | each { testcase })
    }
}

# <testcase name="s" classname="s" time="d">
#   <skipped message=""/>
#   <error message="" type=""></error>
#   <failure message="" type=""></failure>
#   <system-out></system-out>
#   <system-err></system-err>
# </testcase>
def testcase []: record<suite: string, test: string, result: string, output: list<any>> -> record<tag: string, attributes: record, content: list<any>> {
    let test = $in
    {
        tag: "testcase"
        attributes: {
            name: $test.test
            classname: $test.suite
        }
        content: (
            match $test.result {
                "PASS" => []
                "FAIL" => [{
                    tag: "failure"
                    attributes: {
                        type: "Error" # Exception class name
                        message: ""   # Error message, e.g. e.getMessage()
                    }
                    content: [""]     # Failure detail
                }]
                "SKIP" => [{
                    tag: "skipped"
                }]
            }
        )
    }
}

def count []: table<suite: string, test: string, result: string> -> record<total: int, failed: int, skipped: int> {
    let rows = $in
    {
        total: ($rows | length)
        failed: ($rows | where result == "FAIL" | length)
        skipped: ($rows | where result == "SKIP" | length)
    }
}
