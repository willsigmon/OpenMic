import CarPlay

@MainActor
final class CarPlayTemplateManager {
    private let interfaceController: CPInterfaceController
    private var voiceController: CarPlayVoiceController?

    init(interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
    }

    func setupRootTemplate() {
        guard checkQuota() else {
            showQuotaExhaustedInfo()
            return
        }

        voiceController = CarPlayVoiceController(
            interfaceController: interfaceController
        )
    }

    func teardown() async {
        await voiceController?.cleanup()
        voiceController = nil
    }

    // MARK: - Quota

    private func checkQuota() -> Bool {
        // If tier has never been written, bootstrap hasn't run yet - allow access
        guard let raw = UserDefaults.standard.string(forKey: "effectiveTier"),
              let tier = SubscriptionTier(rawValue: raw) else {
            return true
        }

        if tier == .byok { return true }

        let remaining = UserDefaults.standard.integer(forKey: "remainingMinutes")
        return remaining > 0
    }

    private func showQuotaExhaustedInfo() {
        let info = CPInformationTemplate(
            title: "Minutes Exhausted",
            layout: .leading,
            items: [
                CPInformationItem(
                    title: "Upgrade Required",
                    detail: "Open OpenMic on iPhone to upgrade your plan or add API keys."
                )
            ],
            actions: [
                CPTextButton(title: "OK", textStyle: .confirm) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.interfaceController.dismissTemplate(animated: true) { _, _ in }
                    }
                }
            ]
        )
        interfaceController.setRootTemplate(info, animated: true) { _, _ in }
    }
}
