enum MainDestination: Hashable {
    case editor(noteID: String)
    case optionalEditor(noteID: String?)
}
