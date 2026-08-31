import Foundation

public enum SupportTopic: String, Identifiable, CaseIterable, Sendable {
    case liveChat    = "Live Chat"
    case email       = "Email Support"
    case phone       = "Call Us"
    case orderIssues = "Order Issues"
    case returns     = "Returns & Refunds"
    case accountHelp = "Account Help"
    case faq         = "FAQs"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .liveChat:    return "message"
        case .email:       return "envelope"
        case .phone:       return "phone"
        case .orderIssues: return "shippingbox"
        case .returns:     return "arrow.uturn.backward.circle"
        case .accountHelp: return "person.circle"
        case .faq:         return "questionmark.circle"
        }
    }

    public var section: String {
        switch self {
        case .liveChat, .email, .phone: return "Contact"
        default:                        return "Self-service"
        }
    }
}
