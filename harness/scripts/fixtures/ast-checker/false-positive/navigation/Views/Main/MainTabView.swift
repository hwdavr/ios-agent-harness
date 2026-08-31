struct MainTabView {
    var body: some View {
        NavigationStack {
            Text(NotesCopy.title)
                .navigationDestination(for: MainDestination.self) { _ in
                    Text(NotesCopy.title)
                }
        }
        // if let activeDestination = commentOnly { destinationView(activeDestination) }
    }
}
