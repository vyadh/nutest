use std/assert
use ../../std/testing/formatter.nu
use ../../std/testing/theme.nu

# The follow tests provide a unit-test focused view of the formatter module.
# More comprehensive integration tests can be found in output and error tests.

#[test]
def data-and-metadata [] {
    let formatter = formatter preserve

    assert equal ([] | do $formatter) []

    assert equal ([
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ] | do $formatter) [
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ]
}

#[test]
def data-only [] {
    let formatter = formatter unformatted

    assert equal ([] | do $formatter) []

    assert equal ([
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ] | do $formatter) [
        1, 2, 3, "a", "b", "c"
    ]
}

#[test]
def string-with-theme-none [] {
    let formatter = formatter string (theme none)

    assert equal ([] | do $formatter) ""

    assert equal ([
        { stream: "error", items: [1, 2, 3]}
    ] | do $formatter) "1\n2\n3"

    assert equal ([
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ] | do $formatter) (
        "1\n2\n3\na\nb\nc"
    )
}

#[test]
def string-with-theme-standard [] {
    let formatter = formatter string (theme standard)

    assert equal ([] | do $formatter) ""

    assert equal ([
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ] | do $formatter) (
        $"1\n2\n3\n(ansi yellow)a\nb\nc(ansi reset)"
    )
}
