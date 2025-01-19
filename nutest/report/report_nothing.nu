
export def create []: nothing -> record<name: string, save: closure> {
    {
        name: "report nothing"
        save: { || ignore }
    }
}
