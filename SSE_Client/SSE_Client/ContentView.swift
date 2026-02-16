//
//  ContentView.swift
//  SSE_Client
//
//  Created by Alberto Dominguez on 2/15/26.
//

import SwiftUI
import Combine
import EZNetworking

struct StockPrice: Codable {
    let symbol: String
    let price: Double
    let timestamp: Date
}

struct TradingHalt: Codable {
    let symbol: String
    let reason: String
    let duration: Int  // minutes
}

struct MarketStatus: Codable {
    let isOpen: Bool
    let nextOpenTime: Date?
}

class StockTickerViewModel: ObservableObject {
    @Published var currentPrice: Double = 0.0
    @Published var connectionStatus: String = "Disconnected"
    @Published var tradingHalted: Bool = false
    @Published var haltReason: String = ""
    @Published var marketOpen: Bool = false

    private var manager: ServerSentEventManager?

    func start() async throws {
        let config = SSEReconnectionConfig(
            enabled: true,
            maxAttempts: nil,  // Never give up
            initialDelay: 1.0,
            maxDelay: 30.0
        )

        manager = ServerSentEventManager(
            request: SSERequest(url: "http://localhost:8080/stocks/AAPL"),
            reconnectionConfig: config
        )

        // Handle state changes
        Task {
            guard let manager else { return }
            for await state in await manager.stateEvents {
                await updateConnectionStatus(state)
            }
        }

        // Handle different event types
        Task {
            guard let manager else { return }
            for await event in await manager.events {
                await handleServerSentEvent(event)
            }
        }

        try await manager?.connect()
    }

    @MainActor
    private func updateConnectionStatus(_ state: SSEConnectionState) {
        switch state {
        case .connected:
            connectionStatus = "Live"
        case .connecting:
            connectionStatus = "Connecting..."
        case .disconnected(.streamError), .disconnected(.streamEnded):
            connectionStatus = "Reconnecting..."
        default:
            connectionStatus = "Offline"
        }
    }

    private func handleServerSentEvent(_ event: ServerSentEvent) async {
        guard let data = event.data.data(using: .utf8) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Handle based on event type
        switch event.event {
        case "price_update":
            if let price = try? decoder.decode(StockPrice.self, from: data) {
                await updatePrice(price)
            }

        case "trading_halt":
            if let halt = try? decoder.decode(TradingHalt.self, from: data) {
                await handleTradingHalt(halt)
            }

        case "trading_resume":
            await handleTradingResume()

        case "market_status":
            if let status = try? decoder.decode(MarketStatus.self, from: data) {
                await updateMarketStatus(status)
            }

        default:
            // Handle default "message" type or unknown types
            print("Received unknown event type:", event.event ?? "message")
        }
    }

    @MainActor
    private func updatePrice(_ price: StockPrice) {
        currentPrice = price.price
    }

    @MainActor
    private func handleTradingHalt(_ halt: TradingHalt) {
        tradingHalted = true
        haltReason = "\(halt.reason) (Est. \(halt.duration) min)"
    }

    @MainActor
    private func handleTradingResume() {
        tradingHalted = false
        haltReason = ""
    }

    @MainActor
    private func updateMarketStatus(_ status: MarketStatus) {
        marketOpen = status.isOpen
    }

    func stop() async {
        await manager?.terminate()
        manager = nil
    }
}

struct StockTickerView: View {
    @StateObject private var viewModel = StockTickerViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Connection status indicator
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(viewModel.connectionStatus)
                    .font(.caption)
            }

            // Current price
            Text("$\(viewModel.currentPrice, specifier: "%.2f")")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(viewModel.tradingHalted ? .gray : .primary)

            // Trading halt warning
            if viewModel.tradingHalted {
                VStack {
                    Image(systemName: "pause.circle.fill")
                        .font(.title)
                        .foregroundColor(.orange)
                    Text("Trading Halted")
                        .font(.headline)
                    Text(viewModel.haltReason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }

            // Market status
            if !viewModel.marketOpen {
                Text("Market Closed")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .task {
            try? await viewModel.start()
        }
        .onDisappear {
            Task {
                await viewModel.stop()
            }
        }
    }

    private var statusColor: Color {
        switch viewModel.connectionStatus {
        case "Live": return .green
        case "Connecting...", "Reconnecting...": return .yellow
        default: return .gray
        }
    }
}

#Preview {
    StockTickerView()
}
