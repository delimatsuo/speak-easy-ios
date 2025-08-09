# Privacy Policy (v1.0)

Effective date: 2025-08-09

## Summary
We do not retain conversation content. Voice/text is processed in real time to provide translation, then purged. We store minimal metadata to operate the service (e.g., credits, purchases, session duration), never the conversation content.

## Data We Collect
- Account identifiers (Apple/Google UID), display name/email if provided by the provider.
- Credit balances and purchase metadata (productId, seconds granted, timestamps). No receipts stored.
- Session metadata (start/end timestamps, seconds used). No audio/text stored.

## Why We Collect
- Authenticate users; sync credits across devices; process purchases; prevent abuse; improve reliability.

## Processors/Services
- Firebase (Auth/Firestore)
- Google Cloud (Cloud Run; Text‑to‑Speech; Speech‑to‑Text)
- Apple In‑App Purchase

Links to each provider’s privacy policy apply.

## Retention
- Purchases and sessions metadata retained 12 months (automatic TTL), then deleted.
- Credits per user retained while the account is active.

## Security
- TLS 1.3, certificate pinning on iOS.
- API keys/secrets stored in Google Secret Manager; clients do not need a bundled API key.

## Your Choices
- You can sign out at any time. Contact us to request deletion of account metadata.

## Children
The service is not directed to children under 13. Do not use if you are under applicable age without parental consent.

## International Transfers
Data may be processed in regions where our processors operate.

## Contact
support@mervyntalks.app


