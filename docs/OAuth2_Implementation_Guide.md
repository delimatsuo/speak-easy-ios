# OAuth 2.0 Implementation Guide for Universal Translator

## Overview

This document outlines the complete OAuth 2.0 authentication system implemented for the Universal Translator app, featuring enterprise-grade security with PKCE flow, biometric authentication, and comprehensive error handling.

## Architecture Components

### Core Components

1. **OAuth2Manager** (`/iOS/Sources/Authentication/OAuth2Manager.swift`)
   - Main authentication coordinator with PKCE flow
   - ASWebAuthenticationSession integration
   - Token lifecycle management
   - Auto-refresh capability

2. **SecureTokenStore** (`/iOS/Sources/Authentication/SecureTokenStore.swift`)
   - Keychain-based secure storage
   - Biometric authentication (Face ID/Touch ID)
   - Cross-device token synchronization
   - Enterprise-grade encryption

3. **OAuth2Configuration** (`/iOS/Sources/Authentication/OAuth2Configuration.swift`)
   - Provider configurations (Google, Apple, Microsoft, GitHub)
   - URL scheme handling
   - Scope management
   - Configuration validation

4. **OAuth2Error** (`/iOS/Sources/Authentication/OAuth2Error.swift`)
   - Comprehensive error taxonomy
   - Recovery suggestions
   - Security categorization
   - Logging integration

5. **EnhancedAuthenticationManager** (`/iOS/Sources/Authentication/EnhancedAuthenticationManager.swift`)
   - Legacy API key compatibility
   - Anonymous mode support
   - Migration helpers
   - State management

## Security Features

### PKCE (Proof Key for Code Exchange)
- Code verifier/challenge generation using SHA256
- State parameter validation
- MITM attack protection
- RFC 7636 compliance

### Biometric Authentication
- Face ID/Touch ID integration
- Secure token access
- Fallback to device passcode
- Configurable security policies

### Secure Storage
- iOS Keychain Services
- App-specific access groups
- Hardware-backed encryption
- Automatic data protection classes

### Network Security
- TLS 1.2+ enforcement
- Certificate pinning ready
- Secure redirect validation
- Token transmission protection

## Provider Configurations

### Google OAuth 2.0
```swift
authorizationEndpoint: "https://accounts.google.com/o/oauth2/v2/auth"
tokenEndpoint: "https://oauth2.googleapis.com/token"
scopes: ["openid", "email", "profile"]
```

### Apple Sign In
```swift
authorizationEndpoint: "https://appleid.apple.com/auth/authorize"
tokenEndpoint: "https://appleid.apple.com/auth/token"
scopes: ["name", "email"]
```

### Microsoft OAuth 2.0
```swift
authorizationEndpoint: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize"
tokenEndpoint: "https://login.microsoftonline.com/common/oauth2/v2.0/token"
scopes: ["openid", "email", "profile", "User.Read"]
```

### GitHub OAuth
```swift
authorizationEndpoint: "https://github.com/login/oauth/authorize"
tokenEndpoint: "https://github.com/login/oauth/access_token"
scopes: ["user:email", "read:user"]
```

## Implementation Details

### Authentication Flow

1. **Initialization**
   ```swift
   let configuration = OAuth2Configuration()
   let oauth2Manager = OAuth2Manager(configuration: configuration)
   ```

2. **PKCE Parameter Generation**
   ```swift
   // Automatic generation of:
   // - Code verifier (43-128 chars, base64url)
   // - Code challenge (SHA256 hash)
   // - State parameter (security)
   ```

3. **Authentication Session**
   ```swift
   try await oauth2Manager.authenticate(with: .google)
   ```

4. **Token Storage**
   ```swift
   // Secure keychain storage with biometric protection
   try await tokenStore.storeTokens(tokens, for: userId, provider: provider)
   ```

5. **Token Retrieval**
   ```swift
   let accessToken = try await oauth2Manager.getValidAccessToken()
   ```

### Error Handling

The implementation provides comprehensive error handling with categorized error types:

- **Authentication Flow Errors**: User cancellation, invalid URLs, server errors
- **Token Management Errors**: Expired tokens, refresh failures, decryption issues
- **Security Errors**: Biometric failures, keychain access, validation errors
- **Network Errors**: Connection issues, timeouts, invalid responses

### Token Management

#### Automatic Refresh
```swift
// Tokens are automatically refreshed when:
// - Access token expires within 5 minutes
// - API call returns 401 Unauthorized
// - Manual refresh is triggered
```

#### Secure Storage Schema
```
Key Format: "oauth_{token_type}_{provider}_{user_id}"
Access Control: Biometric authentication required
Data Protection: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
```

## Integration Guide

### 1. Configure Info.plist

Add OAuth client IDs and URL schemes:

```xml
<!-- OAuth 2.0 Configuration -->
<key>GOOGLE_CLIENT_ID</key>
<string>$(GOOGLE_CLIENT_ID)</string>
<key>APPLE_CLIENT_ID</key>
<string>$(APPLE_CLIENT_ID)</string>

<!-- URL Schemes for OAuth Callbacks -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.universaltranslator</string>
        </array>
    </dict>
</array>
```

### 2. Environment Configuration

Set up build configuration variables:

```bash
# Development
GOOGLE_CLIENT_ID = "your-google-dev-client-id"
APPLE_CLIENT_ID = "your-apple-dev-client-id"

# Production  
GOOGLE_CLIENT_ID = "your-google-prod-client-id"
APPLE_CLIENT_ID = "your-apple-prod-client-id"
```

### 3. Usage Examples

#### Basic Authentication
```swift
@StateObject private var authManager = EnhancedAuthenticationManager()

// OAuth authentication
try await authManager.authenticateWithOAuth(.google)

// Anonymous mode (legacy)
authManager.continueAnonymously()

// Check authentication state
if authManager.isAuthenticated {
    // User is signed in
}
```

#### Advanced Usage
```swift
// Check if migration is recommended
if authManager.shouldPromptForOAuthMigration {
    // Show migration prompt
    try await authManager.migrateToOAuth(.google)
}

// Handle errors
authManager.$lastError
    .compactMap { $0 }
    .sink { error in
        if error.isRecoverable {
            // Show retry option
        } else {
            // Show error message
        }
    }
```

### 4. UI Integration

Use the provided `OAuth2LoginView` for a complete authentication experience:

```swift
OAuth2LoginView { authenticatedUser in
    // Handle successful authentication
    self.currentUser = authenticatedUser
}
```

## Testing

The implementation includes comprehensive unit tests covering:

- PKCE parameter generation
- Token expiration logic
- Error handling scenarios
- Configuration validation
- Security edge cases

Run tests:
```bash
xcodebuild test -scheme UniversalTranslator -destination 'platform=iOS Simulator,name=iPhone 14'
```

## Migration from API Keys

### Legacy Support
The `EnhancedAuthenticationManager` provides backward compatibility:

```swift
// Legacy method (deprecated)
authManager.authenticateWithAPIKey()  // Maps to continueAnonymously()

// New OAuth method
try await authManager.authenticateWithOAuth(.google)
```

### Migration Strategy

1. **Phase 1**: Deploy OAuth alongside existing API key system
2. **Phase 2**: Prompt active users to migrate to OAuth
3. **Phase 3**: Gradually phase out API key authentication
4. **Phase 4**: OAuth-only authentication

### Credit Migration
Anonymous user credits are preserved during OAuth migration:

```swift
try await authManager.migrateToOAuth(.google)
// Previous credits are automatically transferred
```

## Security Considerations

### Data Protection
- All tokens encrypted in keychain
- Biometric authentication required
- No tokens stored in UserDefaults or plists
- Automatic token cleanup on logout

### Network Security
- HTTPS-only communication
- Certificate validation
- Request/response validation
- Protection against MITM attacks

### Privacy
- Minimal scope requests
- No unnecessary data collection
- User consent for biometric access
- Transparent data usage policies

## Monitoring & Analytics

### Security Logging
```swift
SecurityLogger.shared.logAuthenticationSuccess(provider: "google", userId: userId)
SecurityLogger.shared.logOAuth2Error(error, context: ["provider": "google"])
```

### Metrics Collection
- Authentication success/failure rates
- Token refresh frequencies  
- Error categorization
- Provider usage statistics

## Troubleshooting

### Common Issues

1. **Configuration Errors**
   - Verify client IDs in Info.plist
   - Check URL scheme registration
   - Validate redirect URIs

2. **Keychain Access Issues**
   - Ensure proper entitlements
   - Check access group configuration
   - Verify biometric permissions

3. **Network Connectivity**
   - Handle offline scenarios
   - Implement retry logic
   - Cache valid tokens

### Debug Tools

```swift
// Configuration validation
let configuration = OAuth2Configuration()
let errors = configuration.validateConfigurations()

// Token inspection
let tokens = try await tokenStore.retrieveTokens(for: userId, provider: "google")
print("Token expires at: \(tokens.expiresAt)")
print("Time until expiration: \(tokens.timeUntilExpiration)")
```

## Future Enhancements

### Planned Features
- Multi-factor authentication support
- Enterprise SSO integration
- Device-to-device token sync
- Advanced token management
- Passwordless authentication

### Scalability Considerations
- Token caching strategies
- Concurrent authentication handling
- Background token refresh
- Cross-app token sharing

## Conclusion

This OAuth 2.0 implementation provides enterprise-grade security while maintaining excellent user experience. The modular architecture allows for easy extension and modification while the comprehensive error handling ensures robust operation across all scenarios.

For additional support or questions, refer to the inline documentation in the source code or contact the development team.