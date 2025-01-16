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

#[test]
def "parse with empty option" [] {
    let result = "testing run-tests --reporter table --match-suites " | parse-command-context

    assert equal $result {
        suite: ".*"
        test: ".*"
        path: "."
    }
}

#[test]
def "parse with specified option" [] {
    let result = "testing run-tests --reporter table --match-suites orc" | parse-command-context

    assert equal $result {
        suite: "orc"
        test: ".*"
        path: "."
    }
}

#[test]
def "parse with extra space" [] {
    let result = "testing run-tests  --match-suites  orc" | parse-command-context

    assert equal $result {
        suite: "orc"
        test: ".*"
        path: "."
    }
}

#[test]
def "parse when fully specified" [] {
    let result = "testing run-tests --match-suites sui --match-tests te --path ../something" | parse-command-context

    assert equal $result {
        suite: "sui"
        test: "te"
        path: "../something"
    }
}

#[test]
def "parse with space in value" [] {
    let result = 'testing run-tests --match-tests "parse some" --path ../something'  | parse-command-context

    assert equal $result {
        suite: ".*"
        test: "\"parse some\""
        path: "../something"
    }
}

#[test]
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

#[test]
def "complete tests" [] {
    let temp = $in.temp

    let temp = $in.temp
    let test_file_1 = $temp | path join "test_1.nu"
    let test_file_2 = $temp | path join "test_2.nu"

    "
    #[test]
    def some_foo1 [] { }
    " | save $test_file_1
    '
    #[test]
    def "some foo2" [] { }
    #[ignore]
    def some_foo3 [] { }
    #[before-each]
    def some_foo4 [] { }
    #[test]
    def some_foo5 [] { }
    ' | save $test_file_2


    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "test_bar.nu")
    touch ($temp | path join "test_baz.nu")

    let result = nu-complete tests $"--path ($temp) --match-suites _2 --match-tests foo[1234]"

    assert equal $result.completions [
        # foo1 is excluded via suite pattern
        '"some foo2"' # Commands with spaces are quoted
        "some_foo3"
        # foo4 is excluded as it's not a test
        # foo5 is excluded test pattern
    ]
}
