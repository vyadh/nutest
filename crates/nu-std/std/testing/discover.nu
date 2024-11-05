

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

  let result = list-files $temp ["*"] | sort

  assert equal $result [
    ($temp | path join "any.nu")
    ($temp | path join "test_foo.nu")
  ]

  # todo remove in #[after-each]
  rm --recursive $temp
}

def list-tests [file: string] -> list<string> {
#    do {
#        source $file
#    }
}

def list-files [path: string, stem_patterns: list<string> = [ "test_*", "*_test" ]] -> list<string> {
    $stem_patterns
        | each { |it| expand-stem-pattern $it }
        | each { |pattern| list-files-with-pattern $path $pattern }
        | flatten
}

def list-files-with-pattern [path: string, pattern: string] -> list<string> {
    ls ($path | path join $pattern | into glob)
        | get name
}

def expand-stem-pattern [stem_pattern: string] -> string {
    let with_ext = { stem: $stem_pattern, extension: "nu" } | path join
    ("**" | path join $with_ext)
}
