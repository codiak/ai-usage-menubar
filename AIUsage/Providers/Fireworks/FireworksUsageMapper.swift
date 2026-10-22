import Foundation

enum FireworksUsageMapper {
    static let monthlySpendQuota = "monthly-spend-usd"

    static func map(
        response: HTTPResponse,
        now: Date,
        locale: Locale = .current
    ) throws -> ProviderSnapshot {
        try validate(response, now: now)
        let body = try ProviderParsing.object(from: response.body)
        let quotas = ProviderParsing.array(body["quotas"])
        guard let quota = quotas.first(where: {
            ProviderParsing.string($0["name"])?
                .split(separator: "/")
                .last
                .map(String.init) == monthlySpendQuota
        }) else {
            throw ProviderFailure(
                .invalidResponse,
                "Fireworks monthly spend limit is unavailable for this account."
            )
        }
        guard let limit = ProviderParsing.double(quota["value"]),
              limit > 0 else {
            throw ProviderFailure(
                .invalidResponse,
                "Fireworks quota response changed."
            )
        }
        let used = max(ProviderParsing.double(quota["usage"]) ?? 0, 0)

        return ProviderSnapshot(
            provider: .fireworks,
            planName: planName(limit: limit, locale: locale),
            windows: [
                QuotaWindow(
                    kind: .monthly,
                    usedPercent: min(used / limit * 100, 100),
                    resetsAt: nextMonthStart(after: now)
                )
            ],
            fetchedAt: now
        )
    }

    /// Returns the single account visible to the API key, or nil when the key
    /// can see none or several, since the right one cannot be inferred.
    static func soleAccountID(response: HTTPResponse, now: Date) throws -> String? {
        try validate(response, now: now)
        let body = try ProviderParsing.object(from: response.body)
        let accounts = ProviderParsing.array(body["accounts"])
        guard accounts.count == 1,
              let name = ProviderParsing.string(accounts[0]["name"]) else {
            return nil
        }
        let id = FireworksAuthStore.normalizedAccountID(name)
        return id.isEmpty ? nil : id
    }

    /// Fireworks budgets follow the calendar month in UTC.
    static func nextMonthStart(after date: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: date)
        ) else {
            return nil
        }
        return calendar.date(byAdding: .month, value: 1, to: monthStart)
    }

    private static func validate(_ response: HTTPResponse, now: Date) throws {
        switch response.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw ProviderFailure(
                .authentication,
                "Fireworks API key was rejected. Run `firectl set-api-key`."
            )
        case 429:
            throw ProviderFailure(
                .rateLimited,
                "Fireworks rate limited the usage request.",
                retryAt: ProviderParsing.retryDate(from: response, now: now)
            )
        default:
            throw ProviderFailure(
                response.statusCode >= 500 ? .transient : .invalidResponse,
                "Fireworks usage request failed (\(response.statusCode))."
            )
        }
    }

    private static func planName(limit: Double, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        let amount = formatter.string(from: NSNumber(value: limit)) ??
            "$\(Int(limit))"
        return "\(amount)/mo limit"
    }
}
