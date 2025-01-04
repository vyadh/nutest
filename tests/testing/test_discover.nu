use std/assert
use ../../std/testing/discover.nu

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
def "list suites with none available" [] {
    let temp = $in.temp

    let result = $temp | discover list-suite-files

    assert equal $result []
}

#[test]
def "list suites with specified file path" [] {
    let temp = $in.temp
    let file = $temp | path join "test_foo.nu"
    touch $file

    let result = $file | discover list-suite-files

    assert equal $result [
      ($temp | path join "test_foo.nu")
    ]
}

#[test]
def "list suites with default glob" [] {
    let temp = $in.temp
    mkdir ($temp | path join "subdir")

    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "test-foo2.nu")
    touch ($temp | path join "bar_test.nu")
    touch ($temp | path join "bar2-test.nu")
    touch ($temp | path join "subdir" "test_baz.nu")

    let result = $temp | discover list-suite-files | sort

    assert equal $result [
      ($temp | path join "bar2-test.nu")
      ($temp | path join "bar_test.nu")
      ($temp | path join "subdir" "test_baz.nu")
      ($temp | path join "test-foo2.nu")
      ($temp | path join "test_foo.nu")
    ]
}

#[test]
def "list suites via specified glob" [] {
    let temp = $in.temp

    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "any.nu")

    let result = $temp | discover list-suite-files --glob "**/*.nu" | sort

    assert equal $result [
      ($temp | path join "any.nu")
      ($temp | path join "test_foo.nu")
    ]
}

#[test]
def "list suites with matcher" [] {
    let temp = $in.temp
    mkdir ($temp | path join "subdir")

    touch ($temp | path join "test_foo.nu")
    touch ($temp | path join "test-foo2.nu")
    touch ($temp | path join "bar_test.nu")
    touch ($temp | path join "bar2-test.nu")
    touch ($temp | path join "subdir" "test_baz.nu")

    let result = $temp | discover list-suite-files --matcher "ba" | sort

    assert equal $result [
      ($temp | path join "bar2-test.nu")
      ($temp | path join "bar_test.nu")
      ($temp | path join "subdir" "test_baz.nu")
    ]
}


#[test]
def discover-test-suites [] {
    let temp = $in.temp
    let test_file_1 = $temp | path join "test_1.nu"
    let test_file_2 = $temp | path join "test_2.nu"

    "
    #[test]
    def test_foo [] { }
    # [test]
    def test_bar [] { }
    " | save $test_file_1

    "
    # [test]
    def test_baz [] { }
    def test_qux [] { }
    # [other]
    def test_quux [] { }
    " | save $test_file_2

    let result = discover list-test-suites $temp | sort

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
