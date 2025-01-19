use std/assert
source ../nutest/mod.nu

#[test]
def "display default" [] {
    assert equal (null | select-display null | get name) "display terminal"
}

#[test]
def "display defaults to none with result" [] {
    assert equal (null | select-display "table" | get name) "display none"
    assert equal (null | select-display "summary" | get name) "display none"
}

#[test]
def "display retains specified with result" [] {
    assert equal ("terminal" | select-display "table" | get name) "display terminal"
    assert equal ("table" | select-display "summary" | get name) "display table"
}

#[test]
def "returns default" [] {
    assert equal ("nothing" | select-returns | get name) "returns nothing"
    assert equal (do ("nothing" | select-returns | get results)) null
}

#[test]
def "returns options" [] {
    assert equal ("summary" | select-returns | get name) "returns summary"
    assert equal ("table" | select-returns | get name) "returns table"
}
