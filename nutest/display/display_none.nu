
export def create []: nothing -> record<name: string, start: closure, complete: closure, fire-start: closure, fire-finish: closure> {
    {
        name: "display none"
        start: { || ignore }
        complete: { || ignore }
        fire-start: { |row| ignore }
        fire-finish: { |row| ignore }
    }
}
