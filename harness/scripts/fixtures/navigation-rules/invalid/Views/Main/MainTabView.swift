struct MainTabView {
    var viewModel: MainTabViewModel

    var body: some View {
        if let destination = viewModel.activeDestination {
            destinationView(destination)
        } else if viewModel.isShowingEditor {
            editorView()
        } else {
            homeView()
        }
    }
}
