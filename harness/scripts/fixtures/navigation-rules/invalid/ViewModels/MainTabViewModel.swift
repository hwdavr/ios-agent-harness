final class MainTabViewModel {
    var activeDestination: MainDestination?
    var isShowingEditor = false

    func signOut() async {
        await finishSignOut()
    }

    private func handleSessionExpired() {
        syncAuthState()
    }
}
