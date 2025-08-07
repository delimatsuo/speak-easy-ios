# Security Policy for VoiceBridge iOS App

## API Key Management

All API keys and credentials are stored securely using:

1. **Development**: API keys are stored in a local `api_keys.plist` file, which is excluded from git
2. **Production**: API keys are stored in the iOS Keychain with appropriate access controls
3. **CI/CD**: API keys are stored as encrypted environment variables

## Reporting Security Issues

If you discover a security vulnerability, please email security@yourcompany.com rather than using the public issue tracker.

## API Key Rotation Policy

- API keys are rotated every 90 days
- After a suspected breach, keys are immediately rotated
- Old keys are kept active with reduced permissions for a 24-hour grace period

## Security Testing

The app undergoes regular security testing:

- Static code analysis during CI/CD
- Manual security audits quarterly
- Penetration testing before major releases
