import Foundation

enum SettingsLinks {
    static let supportEmail = "amaykorade5@gmail.com"

    /// Must match App Store Connect → App Information → Privacy Policy URL.
    static let privacyPolicyURLString = "https://steadfast-agate-517.notion.site/Privacy-Policy-36a70f01c48a800b9679f59999dae61c"
    static let termsOfServiceURLString = "https://steadfast-agate-517.notion.site/TERMS-OF-SERVICE-36a70f01c48a8027a102eb88b681f997"
    /// Must match App Store Connect → App Information → Support URL.
    static let supportPageURLString = "https://steadfast-agate-517.notion.site/UPZO-SUPPORT-36b70f01c48a80808358cd3e7022fa9a"
    /// App Store Connect → App Information → Apple ID (numeric). Enables Settings → Leave a review.
    static let appStoreAppleIDString = "6771487796"

    static var writeReviewURL: URL? {
        let trimmed = appStoreAppleIDString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(trimmed)?action=write-review")
    }

    static var hasWriteReviewLink: Bool { writeReviewURL != nil }

    static var privacyPolicyURL: URL? {
        url(from: privacyPolicyURLString)
    }

    static var termsOfServiceURL: URL? {
        url(from: termsOfServiceURLString)
    }

    static var supportPageURL: URL? {
        url(from: supportPageURLString)
    }

    static var hasPublishedPrivacyPolicy: Bool { privacyPolicyURL != nil }
    static var hasPublishedTermsOfService: Bool { termsOfServiceURL != nil }
    static var hasPublishedSupportPage: Bool { supportPageURL != nil }

    static var reportBug: URL {
        mailto(subject: "Bug Report")
    }

    static var requestFeature: URL {
        mailto(subject: "Feature Request")
    }

    static var contactSupport: URL {
        if let supportPageURL { return supportPageURL }
        return mailto(subject: "Support Request")
    }

    private static func url(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme == "https" else {
            return nil
        }
        return url
    }

    private static func mailto(subject: String) -> URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: subject)]
        return components.url ?? URL(string: "mailto:\(supportEmail)")!
    }
}
