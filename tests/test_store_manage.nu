use std/assert
use std/testing *
use ../nutest/store.nu

#[strategy]
def sequential []: nothing -> record {
    { threads: 1 }
}

@before-each
def create-test-dir []: record -> record {
    let temp = mktemp --tmpdir --directory
    {
        temp: $temp
    }
}

@after-each
def cleanup-test-dir [] {
    let context = $in
    rm --recursive $context.temp
}

@test
def "delete a created store" [] {
    let store = store create
    store delete
}

@test
def "delete succeeds even no results tables" [] {
    store delete
}

@test
def "runs with previous unclean run" [] {
    let context = $in
    let temp = $context.temp

    let result = (
        ^$nu.current-exe
            --no-config-file
            --commands $"
                use nutest/store.nu
                store create

                use nutest
                nutest run-tests --path '($temp)' --returns table
            "
    ) | complete

    if $result.exit_code != 0 {
        print $result.stderr
        assert false "Resets result store on new run"
    }
}
