# A reporter that collects results into a table

use store.nu
use formatter.nu

export def create [theme: closure, formatter: closure]: nothing -> record {
  {
    start: {|| ignore }
    complete: {|| ignore }
    results: { query-results $theme $formatter }
    has-return-value: true
    fire-start: {|row| ignore }
    fire-finish: {|row| ignore }
  }
}

def query-results [
  theme: closure
  formatter: closure
]: nothing -> table<suite: string, test: string, result: string, output: string> {

  store query | each {|row|
    {
      suite: ({type: "suite" text: $row.suite} | do $theme)
      test: ({type: "test" text: $row.test} | do $theme)
      result: (format-result $row.result $theme)
      output: ($row.output | do $formatter)
    }
  }
}

def format-result [result: string, theme: closure]: nothing -> string {
  match $result {
    "PASS" => ({type: "pass" text: $result} | do $theme)
    "SKIP" => ({type: "skip" text: $result} | do $theme)
    "FAIL" => ({type: "fail" text: $result} | do $theme)
    _ => $result
  }
}
