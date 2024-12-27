
# A formatter that preserves the data as-is, including stream metadata, useful for tests.
export def preserve []: list<record<stream: string, items: list<any>>> -> closure {
    { $in }
}

# A formatter that preserves the data only, useful for querying.
export def unformatted []: list<record<stream: string, items: list<any>>> -> closure {
    {
        $in
            | each { |message| $message.items }
            | flatten
    }
}

# A formatter that formats items as a string against a theme
# todo rename pretty
export def string [theme: closure]: list<record<stream: string, items: list<any>>> -> closure {
    {
        let events  = $in
        $events
            | each { |event| $event | stream-format $theme }
            | str join "\n"
    }
}

def stream-format [theme: closure]: record<stream: string, items: list<any>> -> string {
    let event = $in
    match $event {
        { stream: "output", items: $items } => {
            $event.items | str join "\n"
        }
        { stream: "error", items: $items } => {
            let text = ($event.items | str join "\n")
            { type: "warning", text: $text } | do $theme
        }
    }
}
