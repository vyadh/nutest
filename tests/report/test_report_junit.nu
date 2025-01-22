use std/assert
source ../../nutest/report/report_junit.nu

#[test]
def "count when no tests" [] {
    let data = []

    let result = $data | count

    assert equal $result {
        total: 0
        failed: 0
        skipped: 0
    }
}

#[test]
def "count with suites of all states" [] {
    let data = [
        { suite: "suite1", test: "test1A", result: "PASS" }
        { suite: "suite1", test: "test1B", result: "PASS" }
        { suite: "suite1", test: "test1C", result: "PASS" }
        { suite: "suite1", test: "test1D", result: "FAIL" }
        { suite: "suite1", test: "test1E", result: "FAIL" }
        { suite: "suite1", test: "test1F", result: "SKIP" }

        { suite: "suite2", test: "test2A", result: "SKIP" }
        { suite: "suite2", test: "test2B", result: "SKIP" }
        { suite: "suite2", test: "test2C", result: "SKIP" }
        { suite: "suite2", test: "test2D", result: "PASS" }
        { suite: "suite2", test: "test2E", result: "PASS" }
        { suite: "suite2", test: "test2F", result: "FAIL" }

        { suite: "suite3", test: "test3A", result: "PASS" }
    ]

    assert equal ($data | count) {
        total: 13
        failed: 3
        skipped: 4
    }

    assert equal ($data | where suite == "suite1" | count) {
        total: 6
        failed: 2
        skipped: 1
    }
    assert equal ($data | where suite == "suite2" | count) {
        total: 6
        failed: 1
        skipped: 3
    }
    assert equal ($data | where suite == "suite3" | count) {
        total: 1
        failed: 0
        skipped: 0
    }
}

#[test]
def "testcase pass" [] {
    let data = { suite: "suite", test: "test", result: "PASS", output: [] }

    let result = $data | testcase | to xml --self-closed

    assert equal $result ('
        <testcase name="test" classname="suite"/>
    ' | strip-xml-whitespace)
}

#[test]
def "testcase fail" [] {
    let data = { suite: "suite", test: "test", result: "FAIL", output: [] }

    let result = $data | testcase | to xml --self-closed

    assert equal $result ('
        <testcase name="test" classname="suite">
          <failure type="Error" message=""></failure>
        </testcase>
    ' | strip-xml-whitespace)
}

#[test]
def "testcase skip" [] {
    let data = { suite: "suite", test: "test", result: "SKIP", output: [] }

    let result = $data | testcase | to xml --self-closed

    assert equal $result ('
        <testcase name="test" classname="suite">
          <skipped/>
        </testcase>
    ' | strip-xml-whitespace)
}

#[test]
def "testsuite with no tests" [] {
    let data = []

    try {
        $data | testsuite | to xml --self-closed
        assert false "Should have errored"
    } catch { |error|
        assert equal $error.msg "No test entries"
    }
}

#[test]
def "testsuite with test stats" [] {
    let data = [[suite, test, result, output];
        ["suite1", "test1A", "PASS", []]
        ["suite1", "test1B", "PASS", []]
        ["suite1", "test1C", "PASS", []]
        ["suite1", "test1D", "FAIL", []]
        ["suite1", "test1E", "FAIL", []]
        ["suite1", "test1F", "SKIP", []]
    ]

    let result = $data | testsuite | to xml --self-closed

    assert str contains $result ('
        <testsuite name="suite1" tests="6" disabled="1" failures="2">
    ' | strip-xml-whitespace)
}

#[test]
def "testsuite with tests" [] {
    let data = [[suite, test, result, output];
        ["suite1", "test1A", "PASS", []]
        ["suite1", "test1B", "FAIL", []]
        ["suite1", "test1C", "SKIP", []]
    ]

    let result = $data | testsuite | to xml --self-closed

    assert equal $result ('
        <testsuite name="suite1" tests="3" disabled="1" failures="1">
            <testcase name="test1A" classname="suite1"/>
            <testcase name="test1B" classname="suite1">
              <failure type="Error" message=""></failure>
            </testcase>
            <testcase name="test1C" classname="suite1">
              <skipped/>
            </testcase>
        </testsuite>
    ' | strip-xml-whitespace)
}

#[test]
def "testsuites with suites" [] {
    let data = [[suite, test, result, output];
        ["suite1", "testA", "PASS", []]
        ["suite2", "testB", "FAIL", []]
        ["suite3", "testC", "SKIP", []]
    ]

    let result = $data | testsuites | to xml --self-closed

    assert equal $result ('
        <testsuites name="nutest" tests="3" disabled="1" failures="1">
            <testsuite name="suite1" tests="1" disabled="0" failures="0">
                <testcase name="testA" classname="suite1"/>
            </testsuite>
            <testsuite name="suite2" tests="1" disabled="0" failures="1">
                <testcase name="testB" classname="suite2">
                  <failure type="Error" message=""></failure>
                </testcase>
            </testsuite>
            <testsuite name="suite3" tests="1" disabled="1" failures="0">
                <testcase name="testC" classname="suite3">
                  <skipped/>
                </testcase>
            </testsuite>
        </testsuites>
    ' | strip-xml-whitespace)
}

def strip-xml-whitespace []: string -> string {
    $in | str trim | str replace --all --regex '>[\n\r ]+<' '><'
}
