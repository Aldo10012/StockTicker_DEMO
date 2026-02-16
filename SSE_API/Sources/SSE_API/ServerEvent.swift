import Vapor

// MARK: - ServerEvent Protocol

protocol ServerEvent {
    var event: String? { get }
    var data: [any Codable] { get }
    var id: String? { get }
    var retry: Int? { get }
}

extension ServerEvent {
    var event: String? { nil }
    var id: String? { nil }
    var retry: Int? { nil }
}

extension ServerEvent {
    var isValid: Bool {
        !data.isEmpty
    }
}

enum ServerEventError: Error {
    case encoding
    case noDataAvailable
}

extension ServerEvent {
    func buffer() throws -> ByteBuffer {
        guard isValid else {
            throw ServerEventError.noDataAvailable
        }

        let jsonDocuments = data.compactMap { try? JSONEncoder().encode($0) }
        let dataContent = jsonDocuments.compactMap { String(data: $0, encoding: .utf8) }

        guard dataContent.isEmpty == false else {
            throw ServerEventError.encoding
        }

        var message = dataContent
            .map { "data: \($0)" }
            .joined(separator: "\n")
            .appending("\n")

        if let event {
            message += "event: \(event)\n"
        }
        if let id {
            message += "id: \(id)\n"
        }
        if let retry {
            message += "retry: \(retry)\n"
        }
        message += "\n"

        return ByteBuffer(string: message)
    }
}

// MARK: - Stock Event Models

struct StockPrice: Codable {
    let symbol: String
    let price: Double
    let timestamp: String
}

struct TradingHalt: Codable {
    let symbol: String
    let reason: String
    let duration: Int
}

struct TradingResume: Codable {
    let symbol: String
}

struct MarketStatus: Codable {
    let isOpen: Bool
    let nextOpenTime: String?
}

// MARK: - Concrete Events

struct StockPriceUpdateEvent: ServerEvent {
    let event: String? = "price_update"
    let data: [any Codable]
    let id: String?
    let retry: Int? = nil

    init(price: StockPrice, id: String) {
        self.data = [price]
        self.id = id
    }
}

struct TradingHaltEvent: ServerEvent {
    let event: String? = "trading_halt"
    let data: [any Codable]
    let id: String?
    let retry: Int? = nil

    init(halt: TradingHalt, id: String) {
        self.data = [halt]
        self.id = id
    }
}

struct TradingResumeEvent: ServerEvent {
    let event: String? = "trading_resume"
    let data: [any Codable]
    let id: String?
    let retry: Int? = nil

    init(resume: TradingResume, id: String) {
        self.data = [resume]
        self.id = id
    }
}

struct MarketStatusEvent: ServerEvent {
    let event: String? = "market_status"
    let data: [any Codable]
    let id: String?
    let retry: Int? = nil

    init(status: MarketStatus, id: String) {
        self.data = [status]
        self.id = id
    }
}
