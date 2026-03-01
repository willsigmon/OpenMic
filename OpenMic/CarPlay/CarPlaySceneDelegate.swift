import CarPlay

@MainActor
final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    private var interfaceController: CPInterfaceController?
    private var templateManager: CarPlayTemplateManager?

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        self.interfaceController = interfaceController
        self.templateManager = CarPlayTemplateManager(
            interfaceController: interfaceController
        )
        templateManager?.setupRootTemplate()
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        let manager = self.templateManager
        self.interfaceController = nil
        self.templateManager = nil
        Task { @MainActor in
            await manager?.teardown()
        }
    }
}
