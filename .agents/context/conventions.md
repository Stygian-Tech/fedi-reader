# Fedi Reader — Code Conventions

## Patterns to Follow

- **Service classes**: `@Observable @MainActor final class`
- **Dependency injection**: Services created in `ContentView`, passed via `@Environment`
- **Concurrency**: `async`/`await` throughout, no Combine
- **Error handling**: Guard-based early returns; errors as enums conforming to `LocalizedError`
- **Logging**: `Logger(subsystem: "app.fedi-reader", category: "ServiceName")`
- **API types**: `Codable` structs with `CodingKeys` mapping snake_case JSON
- **SwiftData models**: `@Model final class` with `@Attribute(.unique)` for IDs
- **Section organization**: `// MARK: -` comments to group related code

## Testing

- **Framework**: Swift Testing (`import Testing`, `@Test`, `@Suite`) — not XCTest
- **Assertions**: `#expect()` — not `XCTAssert`
- **Mocks**: `MockURLProtocol` for network isolation; `MockStatusFactory` for domain objects
- **Test files**: `fedi-readerTests/` directory

## Style

- No linter or formatter configured (no SwiftLint/SwiftFormat)
- PascalCase for types, camelCase for properties/methods
- No external dependencies — all functionality via Apple frameworks
