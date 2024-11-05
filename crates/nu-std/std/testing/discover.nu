
def list-tests [file: string] -> list<string> {
#    do {
#        source $file
#    }
}

# Usage:
#  cd crates/nu-std
#  nu -c 'use std/testing; testing list-files .'

# Test commands?
# test all
# test file <file>
# test path <path>

export def list-files [path: string, pattern: string = "**/{*_test,test_*}.nu"] -> list<string> {
    cd $path
    glob $pattern
}
