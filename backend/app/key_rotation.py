"""
API Key rotation service for enhanced security
"""

import time
import logging
from datetime import datetime, timedelta
from typing import Optional, Dict
from google.cloud import secretmanager
import json

logger = logging.getLogger(__name__)

class KeyRotationService:
    def __init__(self, project_id: str, rotation_period_days: int = 90):
        self.project_id = project_id
        self.rotation_period = timedelta(days=rotation_period_days)
        self.client = secretmanager.SecretManagerServiceClient()
        self.key_metadata: Dict[str, Dict] = {}
        
    def _get_secret_path(self, secret_id: str, version: str = "latest") -> str:
        """Get full path for secret"""
        return f"projects/{self.project_id}/secrets/{secret_id}/versions/{version}"
        
    async def check_rotation_needed(self, secret_id: str) -> bool:
        """Check if key rotation is needed"""
        try:
            # Get current version metadata
            name = self._get_secret_path(secret_id)
            response = self.client.access_secret_version(request={"name": name})
            
            # Extract creation time from metadata
            metadata = response.payload.data.decode("UTF-8")
            try:
                metadata_dict = json.loads(metadata)
                created_time = datetime.fromisoformat(metadata_dict.get("created", ""))
            except (json.JSONDecodeError, ValueError):
                # If no metadata, assume key needs rotation
                return True
                
            # Check if rotation period has elapsed
            return datetime.now() - created_time >= self.rotation_period
            
        except Exception as e:
            logger.error(f"Error checking rotation for {secret_id}: {e}")
            return False
            
    async def rotate_key(self, secret_id: str, new_key: str) -> bool:
        """
        Rotate API key with proper metadata
        """
        try:
            # Create metadata
            metadata = {
                "created": datetime.now().isoformat(),
                "rotated_from": self._get_secret_path(secret_id),
                "rotation_period_days": self.rotation_period.days
            }
            
            # Add metadata to key
            secret_data = json.dumps({
                "key": new_key,
                "metadata": metadata
            }).encode("UTF-8")
            
            # Create new version
            parent = f"projects/{self.project_id}/secrets/{secret_id}"
            response = self.client.add_secret_version(
                request={
                    "parent": parent,
                    "payload": {"data": secret_data}
                }
            )
            
            logger.info(f"Successfully rotated key for {secret_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to rotate key for {secret_id}: {e}")
            return False
            
    async def get_current_key(self, secret_id: str) -> Optional[str]:
        """Get current active key"""
        try:
            name = self._get_secret_path(secret_id)
            response = self.client.access_secret_version(request={"name": name})
            data = response.payload.data.decode("UTF-8")
            
            try:
                # Try to parse as JSON with metadata
                secret_data = json.loads(data)
                return secret_data.get("key")
            except json.JSONDecodeError:
                # If not JSON, return raw data
                return data
                
        except Exception as e:
            logger.error(f"Failed to get current key for {secret_id}: {e}")
            return None
