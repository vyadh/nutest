use ../store.nu

export def create []: nothing -> record {
    {
        name: "return table"
        results: { store query }
    }
}
