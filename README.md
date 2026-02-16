# StockTicker: Full-Stack Server-Sent Events (SSE) Demo

A comprehensive demonstration of **Server-Sent Events (SSE)** using a Swift-based ecosystem. This repository contains a high-frequency, event-driven Stock Ticker API built with **Vapor** and a real-time **iOS Client** utilizing the **EZNetworking SDK**.



## 🚀 The Motivation

While developing SSE support for my **[EZNetworking SDK](https://github.com/Aldo10012/EZNetworking/)**, I noticed a lack of free, reliable SSE-based APIs for testing complex streaming scenarios. To bridge this gap, I built a custom "Stock Ticker" backend. 

This project goes beyond a simple "Hello World" stream by simulating a realistic financial environment, allowing for the testing of:
* **Persistent Connections:** Maintaining long-lived HTTP streams.
* **Weighted Probability:** Simulating market volatility (80% Price Updates, 10% Market Status, etc.).
* **Sequential Integrity:** Ensuring every event arrives with a guaranteed sequential ID for data consistency.

---

## 🏗 Project Structure

The repository is divided into two main components:

### 1. `SSE_API/` (The Backend)
A **Vapor 4** server designed to simulate a live stock market feed.
* **Language:** Swift 6.0+
* **Weighted Selection:** Uses a custom algorithm to distribute events realistically across the stream.
* **Protocol-Oriented:** Implements a robust `ServerEvent` protocol to handle SSE wire-formatting, custom event names, and `retry` intervals.

### 2. `SSE_Client/` (The Frontend)
A **SwiftUI** application that consumes the live feed.
* **Integration:** Utilizes the `ServerSentEventManager` from the **EZNetworking SDK**.
* **Features:** Real-time UI updates, connection state monitoring, and handling of polymorphic event types (Halt, Resume, Price Update).

---

## 🛠 Technical Features

### ⚖️ Weighted Event Distribution
To mimic a real-world market, the API doesn't just send random data. It uses a weighted distribution:
| Event Type | Probability | Purpose |
| :--- | :--- | :--- |
| `price_update` | **80%** | Continuous high-frequency price action. |
| `market_status` | **10%** | Heartbeat pulses for market open/close status. |
| `trading_halt` | **5%** | Rare volatility pauses. |
| `trading_resume` | **5%** | Market returning to an active state. |

### 🔢 Sequential ID Tracking
The server tracks a `currentId` that only increments upon a successful write. This allows the client to detect missed packets or maintain a strict history of the feed.

### 🔄 Built-in Reconnection
The API pushes a `retry` field (set to 1000ms). If the client loses signal, the SSE protocol automatically attempts to re-establish the stream without manual intervention.

---

## 🚦 Getting Started

### Running the API
1. Navigate to the API folder: `cd SSE_API`
2. Run the server: `swift run`
3. The server will start on `http://localhost:8080` (Verify via `http://localhost:8080/stocks/AAPL`)

### Running the iOS Client
1. Open `SSE_Client/StockTicker.xcodeproj` in Xcode.
2. Ensure your simulator/device can reach the API.
3. Build and Run.

---

## 🧪 Verification via Postman

You can verify the stream logic independently of the iOS app:
1. Create a new **GET** request in Postman to `http://localhost:8080/stocks/AAPL`.
2. Postman will detect the `text/event-stream` header and open a persistent event pane.
