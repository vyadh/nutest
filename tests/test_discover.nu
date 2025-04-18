use std/assert
use std/testing *
use ../nutest/discover.nu

@before-each
def setup [] {
    let temp = mktemp --directory
    {
        temp: $temp
    }
}

@after-each
def cleanup [] {
    let context = $in
    rm --recursive $context.temp
}

@test
def "suite files with none available" [] {
    let temp = $in.temp

    let result = $temp | discover suite-files

    assert equal $result []
}

@test
def "suite files with specified file path" [] {
    let temp = $in.temp
    let file = $temp | path join "test_foo.nu"
    touch $file

    let result = $file | discover suite-files

    assert equal $result [
      ($temp | path join "test_foo.nu")
    ]
}

@test
def "suite files with default glob" [] {
    let temp = $in.temp
    mkdir ($temp | path join "subdir")

    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "test-foo2.nu")
    touch ($temp | path join "bar_test.nu")
    touch ($temp | path join "bar2-test.nu")
    touch ($temp | path join "subdir" "test_baz.nu")

    let result = $temp | discover suite-files | sort

    assert equal $result [
      ($temp | path join "bar2-test.nu" | path expand)
      ($temp | path join "bar_test.nu" | path expand)
      ($temp | path join "subdir" "test_baz.nu" | path expand)
      ($temp | path join "test-foo2.nu" | path expand)
      ($temp | path join "test_foo.nu" | path expand)
    ]
}

@test
def "suite files via specified glob" [] {
    let temp = $in.temp

    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "any.nu")

    let result = $temp | discover suite-files --glob "**/*.nu" | sort

    assert equal $result [
      ($temp | path join "any.nu" | path expand)
      ($temp | path join "test_foo.nu" | path expand)
    ]
}

@test
def "suite files with matcher" [] {
    let temp = $in.temp
    mkdir ($temp | path join "subdir")

    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "test-foo2.nu")
    touch ($temp | path join "bar_test.nu")
    touch ($temp | path join "bar2-test.nu")
    touch ($temp | path join "subdir" "test_baz.nu")

    let result = $temp | discover suite-files --matcher "ba" | sort

    assert equal $result [
      ($temp | path join "bar2-test.nu" | path expand)
      ($temp | path join "bar_test.nu" | path expand)
      ($temp | path join "subdir" "test_baz.nu" | path expand)
    ]
}

@test
def "list tests when no suites" [] {
    let temp = $in.temp
    let suite_files = []

    let result = $suite_files | discover test-suites

    assert equal $result []
}

@test
def "tests for all supported test directives" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test.nu"

    "
    use std/testing *

    @test
    def attr-test [] { }
    @ignore
    def attr-ignore [] { }
    @before-all
    def attr-before-all [] { }
    @after-all
    def attr-after-all [] { }
    @before-each
    def attr-before-each [] { }
    @after-each
    def attr-after-each [] { }

    #[test]
    def desc-test [] { }
    #[ignore]
    def desc-ignore [] { }
    #[before-all]
    def desc-before-all [] { }
    #[after-all]
    def desc-after-all [] { }
    #[before-each]
    def desc-before-each [] { }
    #[after-each]
    def desc-after-each [] { }

    #[strategy]
    def desc-strategy [] { }
    " | save $test_file

    let result = [$test_file] | discover test-suites | sort

    assert equal $result [{
        name: "test"
        path: $test_file
        tests: [
            { name: "attr-after-all", type: "after-all" }
            { name: "attr-after-each", type: "after-each" }
            { name: "attr-before-all", type: "before-all" }
            { name: "attr-before-each", type: "before-each" }
            { name: "attr-ignore", type: "ignore" }
            # todo no equivalent to @strategy yet
            #{ name: "attr-strategy", type: "strategy" }
            { name: "attr-test", type: "test" }
            { name: "desc-after-all", type: "after-all" }
            { name: "desc-after-each", type: "after-each" }
            { name: "desc-before-all", type: "before-all" }
            { name: "desc-before-each", type: "before-each" }
            { name: "desc-ignore", type: "ignore" }
            { name: "desc-strategy", type: "strategy" }
            { name: "desc-test", type: "test" }
        ]
    }]
}

@test
def "tests with an unsupported attribute specified first" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test.nu"

    "
    use std/testing *

    alias \"attr other\" = echo

    @other
    @test
    def some-test [] {
    }
    " | save $test_file

    let result = [$test_file] | discover test-suites | sort

    assert equal $result [{
        name: "test"
        path: $test_file
        tests: [
            { name: "some-test", type: "test" }
        ]
    }]
}

@test
def "tests with an unsupported description and supported attribute" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test.nu"

    "
    use std/testing *

    #[other]
    @test
    def some-test [] {
    }
    " | save $test_file

    let result = [$test_file] | discover test-suites | sort

    assert equal $result [{
        name: "test"
        path: $test_file
        tests: [
            { name: "some-test", type: "test" }
        ]
    }]
}

@test
def "tests with an unsupported attribute and supported description" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test.nu"

    "
    use std/testing *

    alias \"attr other\" = echo

    #[test]
    @other
    def some-test [] {
    }
    " | save $test_file

    let result = [$test_file] | discover test-suites | sort

    assert equal $result [{
        name: "test"
        path: $test_file
        tests: [
            { name: "some-test", type: "test" }
        ]
    }]
}

@test
def "tests for unsupported test directives are not discovered" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test.nu"

    "
    use std/testing *

    alias \"attr two\" = echo

    #[one]
    @two
    def some-command [] {
    }

    @test
    def stub [] {
    }
    " | save $test_file

    let result = [$test_file] | discover test-suites | sort

    assert equal $result [{
        name: "test"
        path: $test_file
        tests: [
            { name: "stub", type: "test" }
        ]
    }]
}

@test
def "tests in multiple suites" [] {
    let temp = $in.temp
    let test_file_1 = $temp | path join "test_1.nu"
    let test_file_2 = $temp | path join "test_2.nu"
    let suite_files = [$test_file_1, $test_file_2]

    "
    use std/testing *

    @test
    def test_foo [] { }
    @test
    def test_bar [] { }
    " | save $test_file_1

    "
    use std/testing *

    @test
    def test_baz [] { }
    def test_qux [] { }
    #[other]
    def test_quux [] { }
    " | save $test_file_2

    let result = $suite_files | discover test-suites | sort

    assert equal $result [
        {
            name: "test_1"
            path: $test_file_1
            tests: [
                { name: "test_bar", type: "test" }
                { name: "test_foo", type: "test" }
            ]
        }
        {
            name: "test_2"
            path: $test_file_2
            tests: [
                { name: "test_baz", type: "test" }
                # Unsupported types removed
            ]
        }
    ]
}

@test
def "tests for suites with matcher" [] {
    let temp = $in.temp
    let test_file_1 = $temp | path join "test_1.nu"
    let test_file_2 = $temp | path join "test_2.nu"
    let suite_files = [$test_file_1, $test_file_2]

    "
    use std/testing *

    @test
    def test_foo [] { }
    @ignore
    def test_bar [] { }
    " | save $test_file_1

    "
    use std/testing *

    @test
    def test_baz [] { }
    @ignore
    def test_qux [] { }
    " | save $test_file_2

    let result = $suite_files | discover test-suites --matcher "ba" | sort

    assert equal $result [
        {
            name: "test_1"
            path: $test_file_1
            tests: [
                { name: "test_bar", type: "ignore" }
            ]
        }
        {
            name: "test_2"
            path: $test_file_2
            tests: [
                { name: "test_baz", type: "test" }
            ]
        }
    ]
}

@test
def "tests suites retaining non-tests when no-match" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test.nu"
    let suite_files = [$test_file]

    "
    use std/testing *

    @ignore
    def test_foo [] { }

    @test
    def test_bar [] { }

    @before-each
    def test_baz [] { }

    @after-all
    def test_qux [] { }
    " | save $test_file

    let result = $suite_files | discover test-suites --matcher "ba" | sort

    assert equal $result [
        {
            name: "test"
            path: $test_file
            tests: [
                { name: "test_bar", type: "test" }
                { name: "test_baz", type: "before-each" }
                { name: "test_qux", type: "after-all" }
            ]
        }
    ]
}

@test
def "tests suites excluded suites with no test matches" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test.nu"
    let suite_files = [$test_file]

    "
    use std/testing *

    @test
    def test_foo [] { }

    @test
    def test_bar [] { }

    @ignore
    def test_baz [] { }

    #[other]
    def test_qux [] { }
    " | save $test_file

    let result = $suite_files | discover test-suites --matcher "qux" | sort

    assert equal $result [ ]
}
