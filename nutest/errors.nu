# The backtrace errors in 0.103 are helpful but not while testing Nutest itself
# This script allow us to unpack them so they look like the original error given that
# for whatever reason, `$env.NU_BACKTRACE = 0` doesn't appear to work

export def unwrap-error []: record<msg: string, rendered: string, details: record> -> record<msg: string, rendered: string, details: record> {
    let original = $in | select msg rendered details

    mut error = $original
    mut details = $error.details
    while (("inner" in $details) and ($details.inner | is-not-empty)) {
        $details = $error.details | get inner | first
        $error = $error | merge {
            msg: $details.msg
            details: $details
        }
    }

    $original | merge {
        msg: $error.msg
        rendered: ($error.rendered | last-rendered)
        labels: $details.labels
        details: $error.details
    }
}

def last-rendered []: string -> string {
    let rendered = $in
    let lines = $rendered | lines
    let errors_start = $lines
        | enumerate
        | where item like "^Error: *"
        | get index

    if (($errors_start | is-empty) | (($errors_start | length) == 1)) {
        $rendered
    } else {
        $lines
            | slice ($errors_start | last)..
            | str join "\n"
    }
}
