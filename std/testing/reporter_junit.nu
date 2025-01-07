
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

export def "to junit" []: table<suite: string, test: string, result: string, output: list<any>> -> string {
    $in | testsuites | to xml --self-closed
}

# <testsuites name="s" disabled="n" tests="n" failures="n" errors="n" time="d">
def testsuites []: table<suite: string, test: string, result: string, output: list<any>> -> record {
    let rows = $in
    let stats = $rows | count
    {
        tag: "testsuites"
        attributes: {
            name: "nu-test"
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

def counts []: table<suite: string, test: string, result: string> -> record {
    let results = $in
    {
        totals: ($results | count)
        suites: ($results | counts-by-suite | into record)
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

def counts-by-suite []: table<suite: string, test: string, result: string> -> table<suite: string, total: int, failed: int, skipped: int> {
    let results = $in
    $results
        | group-by suite
        | items { |suite, suite_results|
            {
                $suite: ($suite_results | count)
            }
        }
}
