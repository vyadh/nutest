use std/assert
use harness.nu

# This suite tests use of external tools that would send output to stdout or stderr
# directly rather than what would otherwise be captured by runner aliasing of `print`.

# [before-all]
def setup-tests []: record -> record {
  $in | harness setup-tests
}

# [after-all]
def cleanup-tests []: record -> nothing {
  $in | harness cleanup-tests
}

# [before-each]
def setup-test []: record -> record {
  $in | harness setup-test
}

# [after-each]
def cleanup-test []: record -> nothing {
  $in | harness cleanup-test
}

# [test]
def non-captured-output-is-ignored [] {
  let code = {
    ^$nu.current-exe --version # This will print direct to stdout
    print "Only this text"
  }

  let result = $in | harness run $code

  assert equal ($result | reject suite test) {
    result: "PASS"
    output: [{stream: "output" items: "Only this text"}]
  }
}
