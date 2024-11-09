use std *
use std/assert
use ../../std/testing

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

#  let result = testing list-files $temp | sort
#
#  assert equal $result [
#    ($temp | path join "bar_test.nu")
#    ($temp | path join "subdir" "test_baz.nu")
#    ($temp | path join "test_foo.nu")
#  ]

  # todo remove in #[after-each]
  rm --recursive $temp
}

# [test]
def discover-any-files [] {
  let temp = mktemp --directory

  touch ($temp | path join "test_foo.nu")
  touch ($temp | path join "any.nu")

#  let result = testing list-files $temp "**/*.nu" | sort
#
#  assert equal $result [
#    ($temp | path join "any.nu")
#    ($temp | path join "test_foo.nu")
#  ]

  # todo remove in #[after-each]
  rm --recursive $temp
}

# [test]
def discover-no-files [] {
  let temp = mktemp --directory

#  let result = testing list-files $temp

#  assert equal $result []

  # todo remove in #[after-each]
  rm --recursive $temp
}

# [test]
def discover-command-with-test-annotation [] {
    let temp = mktemp --directory

    "
    #[test]
    def test_foo [] { }
    # [test]
    def test_bar [] { }
    " | save ($temp | path join "test_1.nu")

#    let result = testing list-tests $temp | sort
#
#    assert equal $result [
#      "test_foo"
#      "test_bar"
#    ]

    # todo remove in #[after-each]
    rm --recursive $temp
}

# [test]
def discover-commands-with-test-annotation [] {
    let temp = mktemp --directory

    "
    #[test]
    def test_foo [] { }
    # [test]
    def test_bar [] { }
    " | save ($temp | path join "test_1.nu")

    "
    # [test]
    def test_baz [] { }
    def test_qux [] { }
    " | save ($temp | path join "test_2.nu")

#    let result = testing list-tests $temp | sort
#
#    assert equal $result [
#      "test_foo"
#      "test_bar"
#      "test_baz"
#    ]

    # todo remove in #[after-each]
    rm --recursive $temp
}
