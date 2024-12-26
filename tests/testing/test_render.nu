use std/assert
use ../../std/testing/render.nu
use ../../std/testing/theme.nu

# The follow tests provide a unit-test focused view of the render module.
# More comprehensive integration tests can be found in output and error tests.

#[test]
def data-and-metadata [] {
    let render = render preserve-all

    assert equal ([] | do $render) []

    assert equal ([
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ] | do $render) [
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ]
}

#[test]
def data-only [] {
    let render = render preserve

    assert equal ([] | do $render) []

    assert equal ([
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ] | do $render) [
        1, 2, 3, "a", "b", "c"
    ]
}

#[test]
def string-with-theme-none [] {
    let render = render string (theme none)

    assert equal ([] | do $render) ""

    assert equal ([
        { stream: "error", items: [1, 2, 3]}
    ] | do $render) "1\n2\n3"

    assert equal ([
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ] | do $render) (
        "1\n2\n3\na\nb\nc"
    )
}

#[test]
def string-with-theme-standard [] {
    let render = render string (theme standard)

    assert equal ([] | do $render) ""

    assert equal ([
        { stream: "output", items: [1, 2, 3]}
        { stream: "error", items: ["a", "b", "c"]}
    ] | do $render) (
        $"1\n2\n3\n(ansi yellow)a\nb\nc(ansi reset)"
    )
}
