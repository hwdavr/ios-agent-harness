enum NoteModel {
    case stored
}

enum MoveItemType: String, Equatable {
    case note
}

enum MainDestination: Identifiable, Equatable {
    case editor(noteID: String?, note: NoteModel)
}
