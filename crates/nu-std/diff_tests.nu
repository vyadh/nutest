def main [] {

    use std/testing
    let new = (testing .) | select suite name success

    let old = ^$nu.current-exe -c "source testing.nu; run-tests" | complete

    let new_table = (
        $new
        | insert key { |row| $"($row.suite)+($row.name)" }
        | rename --column { success: result_new }
    )

    let old_table = (
        $old.stderr
        | lines
        | each { |line| $line | ansi strip }
        | where { |line| not ($line | str starts-with "2024") }
        | str replace -r --all '[│ ]+' ' '
        | each { str substring 1.. }
        | where { |line| $line | is-not-empty }
        | drop nth 0
        | each { |line|
            $line
            | split row ' '
            | match $in {
                [$suite, $test] => {result_raw: pass, suite: $suite, name: $test}
                [$result, $suite, $test] => {result_raw: $result, suite: $suite, name: $test}
            }
        }
        | insert result { |row| $row.result_raw == 'pass' }
        | select suite name result
        | insert key { |row| $"($row.suite)+($row.name)" }
        | rename --column { result: result_old }
    )

    let diff = (
        $new_table
        | join -l $old_table key
        | select suite name result_old result_new
        | where { $in.result_old != $in.result_new }
    )

    $diff
}
