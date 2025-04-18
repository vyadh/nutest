# The backtrace errors in 0.103 are helpful but not while testing Nutest itself
# This script allow us to unpack them so they look like the original error given that
# for whatever reason, `$env.NU_BACKTRACE = 0` doesn't appear to work

export def unwrap-error []: record<msg: string, rendered: string, json: string> -> record<msg: string, rendered: string, json: string> {
    let original = $in | select msg rendered json

    mut error = $original
    mut json = $error.json | from json
    while (("inner" in $json) and ($json.inner | is-not-empty)) {
        $json = $error.json | from json | get inner | first
        $error = $error | merge {
            msg: $json.msg
            json: ($json | to json)
        }
    }

    $original | merge {
        msg: $error.msg
        rendered: ($error.rendered | last-rendered)
        labels: $json.labels
        json: $error.json
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
