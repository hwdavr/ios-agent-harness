struct MainTabView {
    @State private var navigationPath: [MainDestination] = []

    var body: some View {
        NavigationStack(path: $navigationPath) {
            homeView()
                .navigationDestination(for: MainDestination.self) { destination in
                    let defaultValue: String? = nil
                    destinationView(destination)
                }
        }
    }
}
