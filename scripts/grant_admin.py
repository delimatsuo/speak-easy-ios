#!/usr/bin/env python3
"""
Grant Firebase Auth custom claim {"admin": true} to a user by email.

Requirements:
- gcloud auth application-default login (ADC) with access to the project
- pip install firebase-admin google-auth

Usage:
  python3 scripts/grant_admin.py <email> [project_id]

Defaults project_id to 'universal-translator-prod' if not provided.
"""
import sys
import os
from typing import Optional

try:
    import firebase_admin
    from firebase_admin import auth, credentials
except Exception as e:
    print("❌ Missing dependencies: firebase-admin. Install with: pip3 install --user firebase-admin")
    sys.exit(1)


def init_app(project_id: str) -> None:
    # Prefer ADC (gcloud application-default login)
    try:
        cred = credentials.ApplicationDefault()
        firebase_admin.initialize_app(cred, {
            'projectId': project_id,
        })
    except Exception as e:
        print(f"❌ Failed to initialize Firebase Admin SDK: {e}")
        print("   Make sure you have run: gcloud auth application-default login")
        sys.exit(1)


def grant_admin(email: str) -> Optional[str]:
    try:
        user = auth.get_user_by_email(email)
    except auth.UserNotFoundError:
        print(f"❌ User not found for email: {email}. Ask the user to sign in once to create an account.")
        return None
    except Exception as e:
        print(f"❌ Failed to lookup user: {e}")
        return None

    claims = user.custom_claims or {}
    if claims.get('admin') is True:
        print(f"ℹ️  User {email} (uid={user.uid}) already has admin=true")
        return user.uid

    claims['admin'] = True
    try:
        auth.set_custom_user_claims(user.uid, claims)
        print(f"✅ Granted admin=true to {email} (uid={user.uid})")
        print("   Note: The user must sign out/in to refresh their ID token.")
        return user.uid
    except Exception as e:
        print(f"❌ Failed to set custom claims: {e}")
        return None


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/grant_admin.py <email> [project_id]")
        sys.exit(2)

    email = sys.argv[1]
    project_id = sys.argv[2] if len(sys.argv) > 2 else 'universal-translator-prod'

    init_app(project_id)
    grant_admin(email)


if __name__ == '__main__':
    main()




