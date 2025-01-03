use std/assert
source ../../std/testing/completions.nu

#[before-each]
def setup [] {
    let temp = mktemp --directory
    {
        temp: $temp
    }
}

#[after-each]
def cleanup [] {
    let context = $in
    rm --recursive $context.temp
}

# [test]
def "parse with empty option" [] {
    let result = "testing run-tests --reporter table --match-suites " | parse-command-context

    assert equal $result {
        suite: ".*"
        test: ".*"
        path: "."
    }
}

# [test]
def "parse with specified option" [] {
    let result = "testing run-tests --reporter table --match-suites orc" | parse-command-context

    assert equal $result {
        suite: "orc"
        test: ".*"
        path: "."
    }
}

# [test]
def "parse with extra space" [] {
    let result = "testing run-tests  --match-suites  orc" | parse-command-context

    assert equal $result {
        suite: "orc"
        test: ".*"
        path: "."
    }
}

# [test]
def "parse when fully specified" [] {
    let result = "testing run-tests --match-suites sui --match-tests te --path ../something" | parse-command-context

    assert equal $result {
        suite: "sui"
        test: "te"
        path: "../something"
    }
}

# [test]
def "parse with prior commands" [] {
    let result = "use std/testing; testing run-tests --match-suites sui --match-tests te --path ../something" | parse-command-context

    assert equal $result {
        suite: "sui"
        test: "te"
        path: "../something"
    }
}

#[test]
def "complete suites" [] {
    let temp = $in.temp
    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "test_bar.nu")
    touch ($temp | path join "test_baz.nu")

    let result = nu-complete suites $"--path ($temp) --match-suites ba"

    assert equal $result.completions [
        "test_bar"
        "test_baz"
    ]
}
