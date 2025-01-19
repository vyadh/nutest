
export def create []: nothing -> record<name: string, run-start: closure, run-complete: closure, test-start: closure, test-complete: closure> {
    {
        name: "display nothing"
        run-start: { || ignore }
        run-complete: { || ignore }
        test-start: { |row| ignore }
        test-complete: { |row| ignore }
    }
}
