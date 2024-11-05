
def list-tests [file: string] -> list<string> {
#    do {
#        source $file
#    }
}

# Usage:
#  cd crates/nu-std
#  nu -c 'use std/testing; testing list-files .'

export def list-files [path: string, stem_patterns: list<string> = [ "test_*", "*_test" ]] -> list<string> {
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
