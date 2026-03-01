import Foundation

@Observable
@MainActor
final class UsageTracker {
    private(set) var remainingMinutes: Int = 10
    private(set) var usedMinutesThisMonth: Int = 0
    private(set) var sessionCount: Int = 0
    private(set) var isSessionActive = false
    private(set) var currentSessionStart: Date?

    private var sessionTimer: Task<Void, Never>?
    var notificationManager: NotificationManager?

    // MARK: - Quota Check

    func canStartSession(tier: SubscriptionTier) -> Bool {
        if tier == .byok { return true }
        return remainingMinutes > 0
    }

    var isQuotaLow: Bool {
        remainingMinutes <= 2 && remainingMinutes > 0
    }

    var isQuotaExhausted: Bool {
        remainingMinutes <= 0
    }

    // MARK: - Session Tracking

    func startSession() {
        guard !isSessionActive else { return }
        isSessionActive = true
        sessionCount += 1
        currentSessionStart = Date()

        sessionTimer = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard let self, !Task.isCancelled else { break }
                self.usedMinutesThisMonth += 1
                if self.remainingMinutes > 0 {
                    self.remainingMinutes -= 1
                }
                // Fire quota alerts at key thresholds
                if self.remainingMinutes == 5 || self.remainingMinutes == 1 || self.remainingMinutes == 0 {
                    self.notificationManager?.scheduleQuotaAlert(
                        minutesRemaining: self.remainingMinutes,
                        tier: .free
                    )
                }
            }
        }
    }

    func endSession(
        provider: String,
        tier: SubscriptionTier,
        deviceID: String,
        userID: String?
    ) async {
        sessionTimer?.cancel()
        sessionTimer = nil
        isSessionActive = false

        guard let start = currentSessionStart else { return }
        let durationSeconds = Int(Date().timeIntervalSince(start))
        currentSessionStart = nil

        // Log usage event to Supabase
        await logUsageEvent(
            provider: provider,
            tier: tier,
            durationSeconds: durationSeconds,
            deviceID: deviceID,
            userID: userID
        )
    }

    // MARK: - Quota Refresh

    func refreshQuota(tier: SubscriptionTier) async {
        if tier == .byok {
            remainingMinutes = .max
            usedMinutesThisMonth = 0
            return
        }

        do {
            let response: [UserQuota] = try await supabase
                .from("user_quotas")
                .select()
                .limit(1)
                .execute()
                .value

            if let quota = response.first {
                remainingMinutes = quota.freeMinutesRemaining
            } else {
                remainingMinutes = tier.monthlyMinutes
            }
        } catch {
            // Fallback to tier default if network fails
            remainingMinutes = tier.monthlyMinutes
        }
    }

    // MARK: - Usage Event Logging

    private func logUsageEvent(
        provider: String,
        tier: SubscriptionTier,
        durationSeconds: Int,
        deviceID: String,
        userID: String?
    ) async {
        do {
            var params: [String: String] = [
                "device_id": deviceID,
                "provider": provider,
                "tier": tier.rawValue,
                "duration_seconds": String(durationSeconds),
            ]
            if let userID {
                params["user_id"] = userID
            }

            try await supabase
                .from("usage_events")
                .insert(params)
                .execute()
        } catch {
            // Non-critical — usage data loss is acceptable
        }
    }
}

// MARK: - Codable Helpers

private struct UserQuota: Codable, Sendable {
    let userId: String?
    let tier: String
    let freeMinutesRemaining: Int
    let paidCreditsCents: Int
    let monthlyResetAt: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case tier
        case freeMinutesRemaining = "free_minutes_remaining"
        case paidCreditsCents = "paid_credits_cents"
        case monthlyResetAt = "monthly_reset_at"
    }
}
