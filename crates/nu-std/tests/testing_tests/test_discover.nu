use std/assert
use ../../std/testing/discover.nu [
    list-files
    list-test-suites
]

# Usage:
#  cd crates/nu-std
#  nu -c 'use std/testing; testing list-files .'

# [test]
def discover-test-files [] {
  let temp = mktemp --directory
  mkdir ($temp | path join "subdir")

  touch ($temp | path join "test_foo.nu")
  touch ($temp | path join "bar_test.nu")
  touch ($temp | path join "subdir" "test_baz.nu")

  let result = list-files $temp | sort

  assert equal $result [
    ($temp | path join "bar_test.nu")
    ($temp | path join "subdir" "test_baz.nu")
    ($temp | path join "test_foo.nu")
  ]

  # todo remove in #[after-each]
  rm --recursive $temp
}

# [test]
def discover-any-files [] {
  let temp = mktemp --directory

  touch ($temp | path join "test_foo.nu")
  touch ($temp | path join "any.nu")

  let result = list-files $temp "**/*.nu" | sort

  assert equal $result [
    ($temp | path join "any.nu")
    ($temp | path join "test_foo.nu")
  ]

  # todo remove in #[after-each]
  rm --recursive $temp
}

# [test]
def discover-no-files [] {
  let temp = mktemp --directory

  let result = list-files $temp

  assert equal $result []

  # todo remove in #[after-each]
  rm --recursive $temp
}

# [test]
def discover-test-suites [] {
    let temp = mktemp --directory
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

    let result = list-test-suites $temp | sort

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

    # todo remove in #[after-each]
    rm --recursive $temp
}
