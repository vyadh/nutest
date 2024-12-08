
export def create [no_theme: bool]: nothing -> closure {
    if $no_theme {
        { theme-none }
    } else {
        { theme-standard }
    }
}

def theme-none []: record -> string {
    match $in {
        { type: _, text: $text } => $text
        { prefix: _ } => ''
        { suffix: _ } => ''
    }
}

def theme-standard []: record -> string {
    match $in {
        { type: "pass", text: $text } => $"✅ (ansi green)($text)(ansi reset)"
        { type: "skip", text: $text } => $"🚧 (ansi yellow)($in.text)(ansi reset)"
        { type: "fail", text: $text }  => $"❌ (ansi red)($in.text)(ansi reset)"
        { type: "warning", text: $text } => $"(ansi yellow)($in.text)(ansi reset)"
        { type: "error", text: $text }  => $"(ansi red)($in.text)(ansi reset)"
        # Below is mainly database queries where we can't wrap text, but can specify manually
        { prefix: "stderr" } => (ansi yellow)
        { suffix: "stderr" } => (ansi reset)
    }
}
