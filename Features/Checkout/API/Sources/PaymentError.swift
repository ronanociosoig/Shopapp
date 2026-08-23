import Foundation

public enum PaymentError: Error, Equatable, Identifiable, Sendable {
    case cardDeclined
    case insufficientFunds
    case expiredCard
    case fraudSuspected
    case networkError
    case unknown

    public var id: String { localizedDescription }

    public var localizedDescription: String {
        switch self {
        case .cardDeclined:       return "Your card was declined. Please try a different card."
        case .insufficientFunds:  return "Insufficient funds. Please check your balance."
        case .expiredCard:        return "Your card has expired. Please update your payment method."
        case .fraudSuspected:     return "This transaction was flagged. Please contact your bank."
        case .networkError:       return "A network error occurred. Please try again."
        case .unknown:            return "An unexpected error occurred. Please try again."
        }
    }

    public var systemImage: String {
        switch self {
        case .cardDeclined, .expiredCard, .fraudSuspected: return "creditcard.trianglebadge.exclamationmark"
        case .insufficientFunds:                           return "banknote"
        case .networkError, .unknown:                      return "wifi.exclamationmark"
        }
    }
}
