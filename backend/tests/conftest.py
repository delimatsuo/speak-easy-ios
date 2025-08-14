"""
Pytest configuration and shared fixtures for Mervyn Talks Backend Tests
"""

import asyncio
import os
import pytest
import pytest_asyncio
from httpx import AsyncClient
from unittest.mock import AsyncMock, MagicMock
from typing import AsyncGenerator, Generator

# Test environment setup
os.environ["ENVIRONMENT"] = "testing"
os.environ["LOG_LEVEL"] = "ERROR"  # Reduce noise in tests
os.environ["GEMINI_API_KEY"] = "test_api_key_12345"
os.environ["DATABASE_URL"] = "sqlite:///./test.db"
os.environ["REDIS_URL"] = "redis://localhost:6379/1"  # Test database

# Import after environment setup
from app.main_voice import app


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def client() -> AsyncGenerator[AsyncClient, None]:
    """Create an async test client for the FastAPI application."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client


@pytest.fixture
def mock_gemini_service(mocker):
    """Mock the Gemini translation service."""
    mock_service = AsyncMock()
    
    # Mock translation response
    mock_service.translate_text.return_value = {
        "translated_text": "Hola mundo",
        "confidence": 0.95,
        "detected_language": "en"
    }
    
    # Mock TTS response
    mock_service.generate_speech.return_value = b"fake_audio_data"
    
    # Mock health check
    mock_service.health_check.return_value = {
        "status": "healthy",
        "model": "gemini-2.5-flash",
        "available": True
    }
    
    mocker.patch("app.services.translation.GeminiTranslationService", return_value=mock_service)
    return mock_service


@pytest.fixture
def mock_redis(mocker):
    """Mock Redis operations."""
    mock_redis = AsyncMock()
    
    # Default Redis operations
    mock_redis.get.return_value = None
    mock_redis.set.return_value = True
    mock_redis.delete.return_value = 1
    mock_redis.exists.return_value = False
    mock_redis.expire.return_value = True
    mock_redis.incr.return_value = 1
    mock_redis.ping.return_value = True
    
    mocker.patch("app.database.redis_client", mock_redis)
    return mock_redis


@pytest.fixture
def mock_rate_limiter(mocker):
    """Mock the rate limiter."""
    mock_limiter = MagicMock()
    mock_limiter.is_allowed.return_value = (True, None)
    mock_limiter.get_usage.return_value = {"requests": 5, "limit": 60, "window": 60}
    
    mocker.patch("app.rate_limiter.RateLimiter", return_value=mock_limiter)
    return mock_limiter


@pytest.fixture
def mock_key_rotation(mocker):
    """Mock the key rotation service."""
    mock_rotation = AsyncMock()
    mock_rotation.should_rotate.return_value = False
    mock_rotation.rotate_key.return_value = "new_test_key"
    mock_rotation.get_current_key.return_value = "test_api_key_12345"
    
    mocker.patch("app.key_rotation.KeyRotationService", return_value=mock_rotation)
    return mock_rotation


@pytest.fixture
def mock_database(mocker):
    """Mock database operations."""
    mock_db = AsyncMock()
    
    # Mock user operations
    mock_db.get_user.return_value = {
        "id": "test_user_123",
        "email": "test@example.com",
        "created_at": "2024-01-01T00:00:00Z"
    }
    
    mock_db.create_user.return_value = {
        "id": "test_user_123",
        "email": "test@example.com",
        "created_at": "2024-01-01T00:00:00Z"
    }
    
    # Mock translation history
    mock_db.save_translation.return_value = True
    mock_db.get_translation_history.return_value = []
    
    mocker.patch("app.database.Database", return_value=mock_db)
    return mock_db


@pytest.fixture
def sample_translation_request():
    """Sample translation request data."""
    return {
        "text": "Hello world",
        "source_language": "en",
        "target_language": "es",
        "include_audio": False,
        "voice": "neutral"
    }


@pytest.fixture
def sample_voice_translation_request():
    """Sample voice translation request data."""
    return {
        "text": "Hello world",
        "source_language": "en", 
        "target_language": "es",
        "include_audio": True,
        "voice": "neutral"
    }


@pytest.fixture
def sample_user_data():
    """Sample user data."""
    return {
        "id": "test_user_123",
        "email": "test@mervyntalks.com",
        "credits_remaining": 600,  # 10 minutes
        "created_at": "2024-01-01T00:00:00Z",
        "last_login": "2024-01-15T10:00:00Z"
    }


@pytest.fixture
def mock_analytics(mocker):
    """Mock analytics collection."""
    mock_analytics = AsyncMock()
    mock_analytics.track_event.return_value = True
    mock_analytics.track_api_request.return_value = True
    mock_analytics.get_metrics.return_value = {
        "total_requests": 1000,
        "successful_requests": 950,
        "error_rate": 0.05
    }
    
    mocker.patch("app.analytics.AnalyticsService", return_value=mock_analytics)
    return mock_analytics


@pytest.fixture
def mock_security_logger(mocker):
    """Mock security logger."""
    mock_logger = MagicMock()
    mock_logger.log_event.return_value = None
    mock_logger.log_security_event.return_value = None
    mock_logger.log_api_access.return_value = None
    
    mocker.patch("app.security.SecurityLogger", return_value=mock_logger)
    return mock_logger


@pytest.fixture(scope="session")
def test_audio_data():
    """Generate test audio data."""
    # Create a simple WAV-like header + data
    import struct
    
    # Simple WAV header (44 bytes) + short audio data
    sample_rate = 16000
    duration = 1  # 1 second
    samples = sample_rate * duration
    
    header = struct.pack('<4sI4s4sIHHIIHH4sI',
                        b'RIFF',
                        36 + samples * 2,  # File size
                        b'WAVE',
                        b'fmt ', 16,  # Format chunk
                        1, 1,  # PCM, mono
                        sample_rate, sample_rate * 2,  # Sample rate, byte rate
                        2, 16,  # Block align, bits per sample
                        b'data', samples * 2)  # Data chunk
    
    # Generate simple sine wave
    import math
    audio_data = b''
    for i in range(samples):
        sample = int(32767 * math.sin(2 * math.pi * 440 * i / sample_rate))
        audio_data += struct.pack('<h', sample)
    
    return header + audio_data


@pytest.fixture
def cleanup_test_files():
    """Cleanup test files after tests."""
    test_files = []
    
    def register_file(filepath):
        test_files.append(filepath)
    
    yield register_file
    
    # Cleanup after test
    import os
    for filepath in test_files:
        try:
            if os.path.exists(filepath):
                os.remove(filepath)
        except Exception:
            pass  # Ignore cleanup errors


# Performance testing fixtures
@pytest.fixture
def performance_timer():
    """Timer for performance testing."""
    import time
    
    class Timer:
        def __init__(self):
            self.start_time = None
            self.end_time = None
        
        def start(self):
            self.start_time = time.time()
        
        def stop(self):
            self.end_time = time.time()
        
        @property
        def elapsed(self):
            if self.start_time and self.end_time:
                return self.end_time - self.start_time
            return None
    
    return Timer()


# Test data factories
class TestDataFactory:
    """Factory for creating test data."""
    
    @staticmethod
    def create_user(email="test@example.com", credits=600):
        """Create test user data."""
        return {
            "id": f"user_{hash(email)}",
            "email": email,
            "credits_remaining": credits,
            "created_at": "2024-01-01T00:00:00Z"
        }
    
    @staticmethod
    def create_translation_request(text="Hello", source="en", target="es"):
        """Create test translation request."""
        return {
            "text": text,
            "source_language": source,
            "target_language": target,
            "include_audio": False
        }
    
    @staticmethod
    def create_api_response(data, status_code=200):
        """Create test API response."""
        return {
            "status_code": status_code,
            "data": data,
            "timestamp": "2024-01-01T00:00:00Z"
        }


@pytest.fixture
def test_factory():
    """Provide test data factory."""
    return TestDataFactory


# Async context manager for database transactions
@pytest_asyncio.fixture
async def db_transaction():
    """Provide database transaction for testing."""
    # This would normally start a database transaction
    # For testing, we'll use a mock
    transaction_mock = AsyncMock()
    transaction_mock.__aenter__ = AsyncMock(return_value=transaction_mock)
    transaction_mock.__aexit__ = AsyncMock(return_value=None)
    transaction_mock.commit = AsyncMock()
    transaction_mock.rollback = AsyncMock()
    
    yield transaction_mock


# Parametrized fixtures for different test scenarios
@pytest.fixture(params=[
    ("en", "es", "Hello world", "Hola mundo"),
    ("es", "en", "Hola mundo", "Hello world"),
    ("fr", "en", "Bonjour", "Hello"),
    ("de", "en", "Guten Tag", "Good day")
])
def translation_test_case(request):
    """Parametrized translation test cases."""
    source_lang, target_lang, source_text, expected_text = request.param
    return {
        "source_language": source_lang,
        "target_language": target_lang,
        "source_text": source_text,
        "expected_text": expected_text
    }


# Markers for test categories
def pytest_configure(config):
    """Configure pytest markers."""
    config.addinivalue_line("markers", "unit: Unit tests")
    config.addinivalue_line("markers", "integration: Integration tests")
    config.addinivalue_line("markers", "e2e: End-to-end tests")
    config.addinivalue_line("markers", "performance: Performance tests")
    config.addinivalue_line("markers", "security: Security tests")
    config.addinivalue_line("markers", "slow: Slow tests that may timeout")


# Test collection hooks
def pytest_collection_modifyitems(config, items):
    """Modify test collection to add markers."""
    for item in items:
        # Add markers based on file path
        if "unit" in str(item.fspath):
            item.add_marker(pytest.mark.unit)
        elif "integration" in str(item.fspath):
            item.add_marker(pytest.mark.integration)
        elif "e2e" in str(item.fspath):
            item.add_marker(pytest.mark.e2e)
        elif "performance" in str(item.fspath):
            item.add_marker(pytest.mark.performance)
        elif "security" in str(item.fspath):
            item.add_marker(pytest.mark.security)
        
        # Mark slow tests
        if "test_load" in item.name or "test_stress" in item.name:
            item.add_marker(pytest.mark.slow)
