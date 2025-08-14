"""
Rate limiter implementation using Redis
"""

import time
from typing import Optional, Tuple
import redis
from fastapi import HTTPException, Request
import logging

logger = logging.getLogger(__name__)

class RateLimiter:
    def __init__(self, redis_url: str = "redis://localhost:6379"):
        try:
            self.redis = redis.Redis.from_url(redis_url, decode_responses=True, socket_connect_timeout=5)
            # Test connection
            self.redis.ping()
            self.redis_available = True
            logger.info(f"Redis connected successfully at {redis_url}")
        except Exception as e:
            logger.warning(f"Redis connection failed: {e}. Rate limiting disabled.")
            self.redis = None
            self.redis_available = False
            
        self.window_size = 60  # 1 minute window
        self.max_requests = {
            "translation": 10,  # Reduced for testing: 10 requests per minute
            "auth": 5,         # 5 requests per minute for auth
            "default": 20      # 20 requests per minute for other endpoints
        }
        
        # In-memory fallback for when Redis is not available
        self.memory_cache = {}
        self.cache_cleanup_interval = 300  # 5 minutes

    async def check_rate_limit(self, request: Request, limit_type: str = "default") -> Tuple[bool, Optional[str]]:
        """
        Check if request should be rate limited
        Returns: (is_allowed, error_message)
        """
        try:
            # Get client identifier (IP or auth token)
            client_id = self._get_client_id(request)
            
            # Get rate limit for this type
            max_requests = self.max_requests.get(limit_type, self.max_requests["default"])
            
            logger.info(f"Rate limit check: {client_id} for {limit_type} (max: {max_requests})")
            
            if self.redis_available and self.redis:
                return await self._check_redis_rate_limit(client_id, limit_type, max_requests)
            else:
                return await self._check_memory_rate_limit(client_id, limit_type, max_requests)
            
        except Exception as e:
            logger.error(f"Unexpected error in rate limiter: {e}")
            # On error, allow request but log
            return True, None
    
    async def _check_redis_rate_limit(self, client_id: str, limit_type: str, max_requests: int) -> Tuple[bool, Optional[str]]:
        """Check rate limit using Redis"""
        try:
            # Redis key format: rate_limit:{type}:{client_id}
            key = f"rate_limit:{limit_type}:{client_id}"
            
            # Current timestamp
            now = int(time.time())
            
            # Clean old requests
            self.redis.zremrangebyscore(key, 0, now - self.window_size)
            
            # Count requests in current window
            request_count = self.redis.zcard(key)
            
            logger.info(f"Redis rate limit: {client_id} has {request_count}/{max_requests} requests")
            
            if request_count >= max_requests:
                logger.warning(f"Rate limit exceeded for {client_id} on {limit_type}")
                return False, f"Rate limit exceeded. Try again in {self.window_size} seconds."
            
            # Add current request
            self.redis.zadd(key, {str(now): now})
            # Set expiry to clean up old keys
            self.redis.expire(key, self.window_size * 2)
            
            return True, None
            
        except redis.RedisError as e:
            logger.error(f"Redis error in rate limiter: {e}")
            # Fallback to memory-based rate limiting
            self.redis_available = False
            return await self._check_memory_rate_limit(client_id, limit_type, max_requests)
    
    async def _check_memory_rate_limit(self, client_id: str, limit_type: str, max_requests: int) -> Tuple[bool, Optional[str]]:
        """Check rate limit using in-memory cache"""
        key = f"{limit_type}:{client_id}"
        now = time.time()
        
        # Initialize if not exists
        if key not in self.memory_cache:
            self.memory_cache[key] = []
        
        # Clean old requests
        self.memory_cache[key] = [
            timestamp for timestamp in self.memory_cache[key]
            if now - timestamp < self.window_size
        ]
        
        request_count = len(self.memory_cache[key])
        
        logger.info(f"Memory rate limit: {client_id} has {request_count}/{max_requests} requests")
        
        if request_count >= max_requests:
            logger.warning(f"Rate limit exceeded for {client_id} on {limit_type}")
            return False, f"Rate limit exceeded. Try again in {self.window_size} seconds."
        
        # Add current request
        self.memory_cache[key].append(now)
        
        return True, None

    def _get_client_id(self, request: Request) -> str:
        """Get unique client identifier"""
        # Try to get Firebase Auth UID from request
        if "Authorization" in request.headers:
            try:
                token = request.headers["Authorization"].split(" ")[1]
                # Use last 8 chars of token as ID
                return f"auth_{token[-8:]}"
            except:
                pass
        
        # Fallback to forwarded IP or direct IP
        forwarded = request.headers.get("X-Forwarded-For")
        if forwarded:
            return forwarded.split(",")[0].strip()
        return request.client.host

    async def require_rate_limit(self, request: Request, limit_type: str = "default"):
        """Dependency to enforce rate limiting"""
        is_allowed, error_message = await self.check_rate_limit(request, limit_type)
        if not is_allowed:
            raise HTTPException(
                status_code=429,
                detail=error_message or "Too many requests"
            )
