
export def create []: nothing -> record<name: string, start: closure, complete: closure, fire-start: closure, fire-finish: closure> {
    {
        name: "display none"
        start: { || ignore }
        results: { null } # todo delete when no longer used
        complete: { || ignore }
        fire-start: { |row| ignore }
        fire-finish: { |row| ignore }
    }
}
