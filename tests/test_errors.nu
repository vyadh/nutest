use std/assert
use std/testing *
source ../nutest/errors.nu

@before-all
def setup [] {
    $env.NU_BACKTRACE = 1
}

@after-all
def teardown [] {
    $env.NU_BACKTRACE = 0
}

@ignore
@test
def normal-error-is-unmodified [] {
    let error = try { error make { msg: "normal error", help: "help text" } } catch { $in }

    let result = $error | unwrap-error

    assert equal $result.msg "normal error"
    assert ($result.rendered | ansi strip | find --regex "^Error: [ ×x\n]+ normal error.*" | is-not-empty)
    assert equal ($result.json | from json | select msg help) {
        msg: "normal error"
        help: "help text"
    }
}

@ignore
@test
def chained-error-is-unwrapped [] {
    def throw-error [] {
        error make { msg: "original error", help: "help text" }
    }
    def calling-function [] {
        throw-error
    }
    let error = try { calling-function } catch { $in }

    let result = $error | unwrap-error

    assert equal $result.msg "original error"
    assert ($result.rendered | ansi strip | find --regex "^Error: [ ×x\n]+ original error.*" | is-not-empty)
    assert equal ($result.json | from json | select msg help) {
        msg: "original error"
        help: "help text"
    }
}

@ignore
@test
def nested-chain-error-is-unwrapped [] {
    def throw-error [] {
        error make { msg: "original error", help: "help text" }
    }
    def nested-error [] {
        throw-error
    }
    def calling-function [] {
        nested-error
    }
    let error = try { calling-function } catch { $in }

    let result = $error | unwrap-error

    assert equal $result.msg "original error"
    assert ($result.rendered | ansi strip | find --regex "^Error: [ ×x\n]+ original error.*" | is-not-empty)
    assert equal ($result.json | from json | select msg help) {
        msg: "original error"
        help: "help text"
    }
}
