import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "Stock Ticker SSE Server is running!"
    }

    // SSE endpoint for stock price updates
    app.get("stocks", ":symbol") { request async throws -> Response in
        guard let symbol = request.parameters.get("symbol") else {
            throw Abort(.badRequest, reason: "Missing stock symbol")
        }

        let body = Response.Body(stream: { writer in
            Task(priority: .background) {
                var currentId = 1

                while true {
                    let event = selectEvent(currentId: currentId, symbol: symbol)

                    do {
                        let buffer = try event.buffer()
                        try await writer.write(.buffer(buffer)).get()
                        currentId += 1
                    } catch {
                        break
                    }

                    try? await Task.sleep(for: .seconds(2))
                }
                try? await writer.write(.end).get()
            }
        })

        let response = Response(status: .ok, body: body)
        response.headers.replaceOrAdd(name: .contentType, value: "text/event-stream")
        response.headers.replaceOrAdd(name: .cacheControl, value: "no-cache")
        response.headers.replaceOrAdd(name: .connection, value: "keep-alive")

        return response
    }
}

// MARK: Event selection

/// Selects a weighted random `ServerEvent` to simulate realistic market activity.
///
/// Distribution Logic:
/// - **80% chance (1-80):** `StockPriceUpdateEvent` - Continuous price action.
/// - **10% chance (81-90):** `MarketStatusEvent` - General market heartbeat.
/// - **5% chance (91-95):** `TradingHaltEvent` - Market volatility pause.
/// - **5% chance (96-100):** `TradingResumeEvent` - Market returning to active state.
func selectEvent(currentId: Int, symbol: String) -> any ServerEvent {
    let idString = "\(currentId)"
    let roll = Int.random(in: 1...100)

    let event: any ServerEvent = switch roll {
    case 1...80:
        StockPriceUpdateEvent(
            price: StockPrice(
                symbol: symbol,
                price: .random(in: 180...185),
                timestamp: ISO8601DateFormatter().string(from: Date())
            ),
            id: idString
        )
    case 81...90:
        MarketStatusEvent(
            status: MarketStatus(isOpen: true, nextOpenTime: nil),
            id: idString
        )
    case 91...95:
        TradingHaltEvent(
            halt: TradingHalt(symbol: symbol, reason: "Volatility pause", duration: 100),
            id: idString
        )
    default:
        // Now included: 5% chance of a resume event
        TradingResumeEvent(
            resume: TradingResume(symbol: symbol),
            id: idString
        )
    }
    return event
}

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
