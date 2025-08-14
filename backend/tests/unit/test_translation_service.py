"""
Unit tests for translation service functionality
"""

import pytest
from unittest.mock import AsyncMock, patch
from app.services.translation import GeminiTranslationService


class TestTranslationService:
    """Test cases for the Gemini translation service."""
    
    @pytest.fixture
    def translation_service(self):
        """Create a translation service instance for testing."""
        return GeminiTranslationService(api_key="test_key")
    
    @pytest.mark.asyncio
    async def test_translate_text_success(self, translation_service, mock_gemini_service):
        """Test successful text translation."""
        # Arrange
        request_data = {
            "text": "Hello world",
            "source_language": "en",
            "target_language": "es"
        }
        
        expected_response = {
            "translated_text": "Hola mundo",
            "confidence": 0.95,
            "detected_language": "en"
        }
        
        mock_gemini_service.translate_text.return_value = expected_response
        
        # Act
        result = await translation_service.translate_text(
            text=request_data["text"],
            source_lang=request_data["source_language"],
            target_lang=request_data["target_language"]
        )
        
        # Assert
        assert result["translated_text"] == expected_response["translated_text"]
        assert result["confidence"] == expected_response["confidence"]
        assert result["detected_language"] == expected_response["detected_language"]
        
        mock_gemini_service.translate_text.assert_called_once_with(
            text="Hello world",
            source_lang="en",
            target_lang="es"
        )
    
    @pytest.mark.asyncio
    async def test_translate_text_empty_input(self, translation_service):
        """Test translation with empty text input."""
        with pytest.raises(ValueError, match="Text cannot be empty"):
            await translation_service.translate_text(
                text="",
                source_lang="en",
                target_lang="es"
            )
    
    @pytest.mark.asyncio
    async def test_translate_text_invalid_language(self, translation_service):
        """Test translation with invalid language codes."""
        with pytest.raises(ValueError, match="Invalid language code"):
            await translation_service.translate_text(
                text="Hello",
                source_lang="invalid",
                target_lang="es"
            )
    
    @pytest.mark.asyncio
    async def test_generate_speech_success(self, translation_service, mock_gemini_service):
        """Test successful speech generation."""
        # Arrange
        text = "Hola mundo"
        expected_audio = b"fake_audio_data"
        
        mock_gemini_service.generate_speech.return_value = expected_audio
        
        # Act
        result = await translation_service.generate_speech(
            text=text,
            language="es",
            voice="neutral"
        )
        
        # Assert
        assert result == expected_audio
        mock_gemini_service.generate_speech.assert_called_once_with(
            text=text,
            language="es",
            voice="neutral"
        )
    
    @pytest.mark.asyncio
    async def test_generate_speech_long_text(self, translation_service):
        """Test speech generation with text that's too long."""
        long_text = "a" * 1001  # Assuming 1000 char limit
        
        with pytest.raises(ValueError, match="Text too long"):
            await translation_service.generate_speech(
                text=long_text,
                language="en",
                voice="neutral"
            )
    
    @pytest.mark.asyncio
    async def test_health_check_success(self, translation_service, mock_gemini_service):
        """Test successful health check."""
        # Arrange
        expected_health = {
            "status": "healthy",
            "model": "gemini-2.5-flash",
            "available": True
        }
        
        mock_gemini_service.health_check.return_value = expected_health
        
        # Act
        result = await translation_service.health_check()
        
        # Assert
        assert result["status"] == "healthy"
        assert result["available"] is True
        mock_gemini_service.health_check.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_translate_with_retry_logic(self, translation_service, mock_gemini_service):
        """Test translation with retry logic on API failures."""
        # Arrange: First call fails, second succeeds
        mock_gemini_service.translate_text.side_effect = [
            Exception("API timeout"),
            {"translated_text": "Hola mundo", "confidence": 0.95, "detected_language": "en"}
        ]
        
        # Act
        result = await translation_service.translate_text(
            text="Hello world",
            source_lang="en", 
            target_lang="es"
        )
        
        # Assert
        assert result["translated_text"] == "Hola mundo"
        assert mock_gemini_service.translate_text.call_count == 2
    
    @pytest.mark.asyncio
    async def test_rate_limit_handling(self, translation_service, mock_gemini_service):
        """Test handling of rate limit responses."""
        # Arrange
        from app.exceptions import RateLimitExceeded
        mock_gemini_service.translate_text.side_effect = RateLimitExceeded("Rate limit exceeded")
        
        # Act & Assert
        with pytest.raises(RateLimitExceeded):
            await translation_service.translate_text(
                text="Hello",
                source_lang="en",
                target_lang="es"
            )
    
    def test_supported_languages(self, translation_service):
        """Test that supported languages are correctly defined."""
        supported = translation_service.get_supported_languages()
        
        # Check that common languages are supported
        assert "en" in supported
        assert "es" in supported
        assert "fr" in supported
        assert "de" in supported
        assert "it" in supported
        assert "pt" in supported
        assert "ru" in supported
        assert "ja" in supported
        assert "ko" in supported
        assert "zh" in supported
        assert "ar" in supported
        assert "hi" in supported
        
        # Ensure we have at least 12 languages
        assert len(supported) >= 12
    
    def test_language_validation(self, translation_service):
        """Test language code validation."""
        # Valid languages should pass
        assert translation_service.validate_language("en") is True
        assert translation_service.validate_language("es") is True
        
        # Invalid languages should fail
        assert translation_service.validate_language("invalid") is False
        assert translation_service.validate_language("") is False
        assert translation_service.validate_language(None) is False
    
    @pytest.mark.asyncio
    async def test_translation_caching(self, translation_service, mock_redis):
        """Test that translations are properly cached."""
        # Arrange
        cache_key = "trans:en:es:hello"
        cached_result = '{"translated_text": "hola", "confidence": 0.95}'
        
        mock_redis.get.return_value = cached_result
        
        # Act
        result = await translation_service.get_cached_translation(
            text="hello",
            source_lang="en",
            target_lang="es"
        )
        
        # Assert
        assert result is not None
        mock_redis.get.assert_called_with(cache_key)
    
    @pytest.mark.asyncio
    async def test_translation_cache_miss(self, translation_service, mock_redis, mock_gemini_service):
        """Test behavior when translation is not in cache."""
        # Arrange
        mock_redis.get.return_value = None  # Cache miss
        expected_translation = {
            "translated_text": "hola",
            "confidence": 0.95,
            "detected_language": "en"
        }
        mock_gemini_service.translate_text.return_value = expected_translation
        
        # Act
        result = await translation_service.translate_text(
            text="hello",
            source_lang="en",
            target_lang="es"
        )
        
        # Assert
        assert result["translated_text"] == "hola"
        # Verify cache was checked and result was cached
        mock_redis.get.assert_called()
        mock_redis.set.assert_called()


class TestTranslationValidation:
    """Test cases for translation input validation."""
    
    def test_text_length_validation(self):
        """Test text length validation."""
        from app.services.translation import validate_text_length
        
        # Valid lengths
        assert validate_text_length("Hello") is True
        assert validate_text_length("a" * 500) is True
        
        # Invalid lengths
        assert validate_text_length("") is False
        assert validate_text_length("a" * 5001) is False
        assert validate_text_length(None) is False
    
    def test_language_pair_validation(self):
        """Test language pair validation."""
        from app.services.translation import validate_language_pair
        
        # Valid pairs
        assert validate_language_pair("en", "es") is True
        assert validate_language_pair("fr", "de") is True
        
        # Invalid pairs (same language)
        assert validate_language_pair("en", "en") is False
        
        # Invalid language codes
        assert validate_language_pair("invalid", "es") is False
        assert validate_language_pair("en", "invalid") is False
    
    def test_voice_parameter_validation(self):
        """Test voice parameter validation."""
        from app.services.translation import validate_voice_parameter
        
        # Valid voices
        assert validate_voice_parameter("neutral") is True
        assert validate_voice_parameter("male") is True
        assert validate_voice_parameter("female") is True
        
        # Invalid voices
        assert validate_voice_parameter("invalid") is False
        assert validate_voice_parameter("") is False
        assert validate_voice_parameter(None) is False


class TestTranslationPerformance:
    """Test cases for translation performance."""
    
    @pytest.mark.asyncio
    async def test_translation_response_time(self, translation_service, mock_gemini_service, performance_timer):
        """Test that translation completes within acceptable time."""
        # Arrange
        mock_gemini_service.translate_text.return_value = {
            "translated_text": "Hola mundo",
            "confidence": 0.95,
            "detected_language": "en"
        }
        
        # Act
        performance_timer.start()
        await translation_service.translate_text(
            text="Hello world",
            source_lang="en",
            target_lang="es"
        )
        performance_timer.stop()
        
        # Assert (should complete in under 2 seconds)
        assert performance_timer.elapsed < 2.0
    
    @pytest.mark.asyncio
    async def test_concurrent_translations(self, translation_service, mock_gemini_service):
        """Test handling of concurrent translation requests."""
        import asyncio
        
        # Arrange
        mock_gemini_service.translate_text.return_value = {
            "translated_text": "Translated",
            "confidence": 0.95,
            "detected_language": "en"
        }
        
        # Act - Send 10 concurrent requests
        tasks = []
        for i in range(10):
            task = translation_service.translate_text(
                text=f"Text {i}",
                source_lang="en",
                target_lang="es"
            )
            tasks.append(task)
        
        results = await asyncio.gather(*tasks)
        
        # Assert
        assert len(results) == 10
        for result in results:
            assert result["translated_text"] == "Translated"
