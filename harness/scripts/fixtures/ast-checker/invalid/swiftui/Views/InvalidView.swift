struct InvalidView: View {
    var body: some View {
        VStack { ForEach(items) { _ in Button("Tap") {} } }
        Color.red
        Text("Fixture").accessibilityIdentifier("fixture_\(item.id)")
    }
}
