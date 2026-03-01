# Fedi Reader — Build & Test Commands

```bash
# Build (iOS Simulator)
xcodebuild -scheme "fedi-reader" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' build

# Run all tests
xcodebuild -scheme "fedi-reader" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' test

# Unit tests only
xcodebuild -scheme "fedi-reader" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:fedi-readerTests test

# Single test suite
xcodebuild -scheme "fedi-reader" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:fedi-readerTests/HTMLParserTests test

# Single test method
xcodebuild -scheme "fedi-reader" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -only-testing:fedi-readerTests/HTMLParserTests/extractsLinks test

# Clean
xcodebuild -scheme "fedi-reader" clean
```

For more commands (including WARP guidance), see [WARP.md](../../WARP.md).
