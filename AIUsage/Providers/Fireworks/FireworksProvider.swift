import Foundation

actor FireworksProvider: UsageProvider {
    nonisolated let id = ProviderID.fireworks

    private let authStore: FireworksAuthStore
    private let client: FireworksUsageClient
    private let dateProvider: DateProviding
    private var discoveredAccountID: (apiKey: String, accountID: String)?

    init(
        authStore: FireworksAuthStore = FireworksAuthStore(),
        client: FireworksUsageClient = FireworksUsageClient(),
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        self.authStore = authStore
        self.client = client
        self.dateProvider = dateProvider
    }

    func fetch() async throws -> ProviderSnapshot {
        guard let auth = authStore.load() else {
            throw ProviderFailure(
                .authentication,
                "Not logged in. Run `nexus login` or `firectl set-api-key`."
            )
        }

        let accountID = try await resolveAccountID(auth)
        let response: HTTPResponse
        do {
            response = try await client.fetchQuotas(
                apiKey: auth.apiKey,
                accountID: accountID
            )
        } catch let failure as ProviderFailure {
            throw failure
        } catch {
            throw ProviderFailure(.transient, "Fireworks could not be reached.")
        }
        return try FireworksUsageMapper.map(
            response: response,
            now: dateProvider.now()
        )
    }

    private func resolveAccountID(_ auth: FireworksAuth) async throws -> String {
        if let accountID = auth.accountID, !accountID.isEmpty {
            return accountID
        }
        if let discoveredAccountID, discoveredAccountID.apiKey == auth.apiKey {
            return discoveredAccountID.accountID
        }

        let response: HTTPResponse
        do {
            response = try await client.fetchAccounts(apiKey: auth.apiKey)
        } catch let failure as ProviderFailure {
            throw failure
        } catch {
            throw ProviderFailure(.transient, "Fireworks could not be reached.")
        }
        guard let accountID = try FireworksUsageMapper.soleAccountID(
            response: response,
            now: dateProvider.now()
        ) else {
            throw ProviderFailure(
                .authentication,
                "Fireworks account is unknown. Add `account_id` to ~/.fireworks/auth.ini."
            )
        }
        discoveredAccountID = (auth.apiKey, accountID)
        return accountID
    }
}
