#!/bin/bash

# SECURITY: Script to clean up exposed API keys from git history
# This script helps remove sensitive information from git history
# and sets up proper secret management going forward

set -e  # Exit on error

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}🔒 Speak Easy Security Remediation Tool${NC}"
echo -e "${YELLOW}This script will help clean up exposed API keys and implement secure credential management${NC}\n"

# Check if BFG is installed
check_bfg() {
  if ! command -v bfg &> /dev/null; then
    echo -e "${RED}BFG Repo-Cleaner not found. Installing...${NC}"
    # Check if Homebrew is installed
    if command -v brew &> /dev/null; then
      brew install bfg
    else
      echo -e "${RED}Error: Homebrew not found. Please install BFG manually:${NC}"
      echo "Visit: https://rtyley.github.io/bfg-repo-cleaner/"
      exit 1
    fi
  fi
  echo -e "${GREEN}✓ BFG Repo-Cleaner is installed${NC}"
}

# Create replacement patterns file
create_replacement_file() {
  echo -e "${YELLOW}Creating replacement patterns file...${NC}"
  cat > replace-patterns.txt << EOL
# Google API Key patterns (AIza...)
regex:AIza[0-9A-Za-z\\-_]{35,40}==>GOOGLE_API_KEY_REDACTED

# Test API Keys in security tests 
regex:sk-[0-9a-zA-Z]{32,64}==>TEST_API_KEY_REDACTED
EOL
  echo -e "${GREEN}✓ Replacement patterns file created${NC}"
}

# Clean Git history using BFG
clean_git_history() {
  echo -e "${YELLOW}Cleaning Git history... (this may take a while)${NC}"
  
  # Make sure we have the full history
  echo "Fetching full git history..."
  git fetch --all
  
  # Use BFG to replace secrets
  bfg --replace-text replace-patterns.txt
  
  # Clean up refs and force garbage collection
  git reflog expire --expire=now --all
  git gc --prune=now --aggressive
  
  echo -e "${GREEN}✓ Git history cleaned${NC}"
  echo -e "${YELLOW}NOTE: You will need to force push these changes:${NC}"
  echo -e "      git push --force"
}

# Create secure key storage solution
setup_secure_key_storage() {
  echo -e "${YELLOW}Setting up secure key storage...${NC}"
  
  # Create API key template file
  cat > api_keys.template.plist << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GoogleTranslateAPIKey</key>
    <string>YOUR_GOOGLE_API_KEY_HERE</string>
    <key>FirebaseAPIKey</key>
    <string>YOUR_FIREBASE_API_KEY_HERE</string>
</dict>
</plist>
EOL

  # Add to gitignore if not already there
  if ! grep -q "api_keys.plist" .gitignore; then
    echo "api_keys.plist" >> .gitignore
    echo -e "${GREEN}✓ Added api_keys.plist to .gitignore${NC}"
  fi
  
  echo -e "${GREEN}✓ Secure key storage template created${NC}"
  echo -e "${YELLOW}ACTION REQUIRED: Create your actual api_keys.plist file from the template${NC}"
}

# Create KeychainManager for iOS app
create_keychain_manager() {
  echo -e "${YELLOW}Creating secure KeychainManager...${NC}"
  
  mkdir -p iOS/Utilities
  
  cat > iOS/Utilities/KeychainManager.swift << EOL
//
//  KeychainManager.swift
//  Speak Easy
//
//  Created on $(date '+%Y-%m-%d')
//

import Foundation
import Security

/// Secure API key management using the iOS Keychain
class KeychainManager {
    
    static let shared = KeychainManager()
    
    private init() {}
    
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case invalidItemFormat
        case unexpectedStatus(OSStatus)
    }
    
    /// Store API key securely in Keychain
    func storeAPIKey(_ key: String, forService service: String) throws {
        guard let data = key.data(using: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        
        // Create query for Keychain
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Retrieve API key from Keychain
    func retrieveAPIKey(forService service: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = dataTypeRef as? Data, 
              let key = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidItemFormat
        }
        
        return key
    }
    
    /// Delete API key from Keychain
    func deleteAPIKey(forService service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Load API key from bundle during development, or keychain in production
    func getAPIKey(forService service: String) -> String? {
        #if DEBUG
        // In debug mode, try to load from plist
        if let path = Bundle.main.path(forResource: "api_keys", ofType: "plist"),
           let keys = NSDictionary(contentsOfFile: path),
           let key = keys[service] as? String {
            return key
        }
        #endif
        
        // In production or if plist fails, try keychain
        do {
            return try retrieveAPIKey(forService: service)
        } catch {
            print("Failed to retrieve API key: \(error)")
            return nil
        }
    }
}
EOL

  echo -e "${GREEN}✓ KeychainManager.swift created${NC}"
}

# Create documentation
create_security_documentation() {
  echo -e "${YELLOW}Creating security documentation...${NC}"
  
  cat > SECURITY.md << EOL
# Security Policy for Speak Easy iOS App

## API Key Management

All API keys and credentials are stored securely using:

1. **Development**: API keys are stored in a local \`api_keys.plist\` file, which is excluded from git
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
EOL

  echo -e "${GREEN}✓ SECURITY.md created${NC}"
}

# Main execution
main() {
  check_bfg
  create_replacement_file
  clean_git_history
  setup_secure_key_storage
  create_keychain_manager
  create_security_documentation
  
  echo -e "\n${GREEN}${BOLD}✅ Security remediation completed!${NC}"
  echo -e "${YELLOW}Next steps:${NC}"
  echo -e "1. Create your api_keys.plist file from the template"
  echo -e "2. Force push the cleaned git history with 'git push --force'"
  echo -e "3. Update the iOS code to use the new KeychainManager"
  echo -e "4. ROTATE YOUR API KEYS on the service provider's website"
}

# Ask for confirmation
echo -e "${YELLOW}${BOLD}⚠️  WARNING: This will modify git history!${NC}"
echo -e "${YELLOW}You should back up your repository before proceeding.${NC}"
read -p "Do you want to continue? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  main
else
  echo -e "${RED}Operation cancelled.${NC}"
  exit 0
fi
