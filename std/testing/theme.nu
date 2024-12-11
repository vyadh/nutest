
export def none []: record -> closure {
    {
        match $in {
            { type: _, text: $text } => $text
            { prefix: _ } => ''
            { suffix: _ } => ''
        }
    }
}

export def standard []: record -> closure {
    {
        match $in {
            { type: "pass", text: $text } => $"✅ (ansi green)($text)(ansi reset)"
            { type: "skip", text: $text } => $"🚧 (ansi yellow)($in.text)(ansi reset)"
            { type: "fail", text: $text } => $"❌ (ansi red)($in.text)(ansi reset)"
            { type: "warning", text: $text } => $"(ansi yellow)($in.text)(ansi reset)"
            { type: "error", text: $text } => $"(ansi red)($in.text)(ansi reset)"
            { type: "suite", text: $text } => $"(ansi light_blue)($in.text)(ansi reset)"
            { type: "test", text: $text } => $in.text
            # Below is mainly database queries where we can't wrap text, but can specify manually
            { prefix: "stderr" } => (ansi yellow)
            { suffix: "stderr" } => (ansi reset)
        }
    }
}
