import Foundation

enum LegalDocument: String, CaseIterable, Identifiable {
    case termsOfUse = "TermsOfUse"
    case termsOfSale = "TermsOfSale"
    case privacyPolicy = "PrivacyPolicy"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .termsOfUse: return "Conditions Générales d'Utilisation"
        case .termsOfSale: return "Conditions Générales de Vente"
        case .privacyPolicy: return "Politique de confidentialité"
        }
    }

    var icon: String {
        switch self {
        case .termsOfUse: return "doc.text.fill"
        case .termsOfSale: return "cart.fill"
        case .privacyPolicy: return "lock.shield.fill"
        }
    }

    var content: String {
        guard let url = Bundle.main.url(forResource: rawValue, withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }
}
