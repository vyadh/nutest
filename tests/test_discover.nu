use std/assert
use ../nutest/discover.nu

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
def "suite files with none available" [] {
    let temp = $in.temp

    let result = $temp | discover suite-files

    assert equal $result []
}

#[test]
def "suite files with specified file path" [] {
    let temp = $in.temp
    let file = $temp | path join "test_foo.nu"
    touch $file

    let result = $file | discover suite-files

    assert equal $result [
      ($temp | path join "test_foo.nu")
    ]
}

#[test]
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

#[test]
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

#[test]
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

#[test]
def "list tests when no suites" [] {
    let temp = $in.temp
    let suite_files = []

    let result = $suite_files | discover test-suites

    assert equal $result []
}

#[test]
def "tests suites found" [] {
    let temp = $in.temp
    let test_file_1 = $temp | path join "test_1.nu"
    let test_file_2 = $temp | path join "test_2.nu"
    let suite_files = [$test_file_1, $test_file_2]

    "
    #[test]
    def test_foo [] { }
    #[test]
    def test_bar [] { }
    " | save $test_file_1

    "
    #[test]
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
                { name: "test_quux", type: "other" }
            ]
        }
    ]
}

#[test]
def "tests suites with matcher" [] {
    let temp = $in.temp
    let test_file_1 = $temp | path join "test_1.nu"
    let test_file_2 = $temp | path join "test_2.nu"
    let suite_files = [$test_file_1, $test_file_2]

    "
    #[test]
    def test_foo [] { }
    #[ignore]
    def test_bar [] { }
    " | save $test_file_1

    "
    #[test]
    def test_baz [] { }
    #[ignore]
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

#[test]
def "tests suites retaining non-tests when no-match" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test.nu"
    let suite_files = [$test_file]

    "
    #[ignore]
    def test_foo [] { }

    #[test]
    def test_bar [] { }

    #[before-each]
    def test_baz [] { }

    #[after-all]
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

#[test]
def "tests suites excluded suites with no test matches" [] {
    let temp = $in.temp
    let test_file = $temp | path join "test.nu"
    let suite_files = [$test_file]

    "
    #[test]
    def test_foo [] { }

    #[test]
    def test_bar [] { }

    #[ignore]
    def test_baz [] { }

    #[other]
    def test_qux [] { }
    " | save $test_file

    let result = $suite_files | discover test-suites --matcher "qux" | sort

    assert equal $result [ ]
}
