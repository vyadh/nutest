
# A formatter that preserves the data as-is, including stream metadata, useful for tests.
# todo 'preserved' more consistent?
export def preserve []: table<stream: string, items: list<any>> -> closure {
    { $in }
}

# A formatter that preserves the data only, useful for querying.
export def unformatted []: table<stream: string, items: list<any>> -> closure {
    {
        $in
            | each { |message| $message.items }
            | flatten
    }
}

# todo add `table`

# A formatter that formats items as a string against a theme
# todo rename pretty
export def string [theme: closure]: table<stream: string, items: list<any>> -> closure {
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
