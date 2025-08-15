"""
Universal Translator Backend API - Voice Translation with TTS
Real-time voice translation with audio responses
"""

import os
import logging
import json
import time
import base64
import io
from contextlib import asynccontextmanager
from typing import Optional, Dict, Any

from fastapi import FastAPI, HTTPException, Request, File, UploadFile, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from google.cloud import secretmanager, texttospeech, speech, logging as cloud_logging
import google.generativeai as genai
from pydantic import BaseModel, Field
import httpx
from gtts import gTTS
import tempfile

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize clients with error handling
try:
    secret_client = secretmanager.SecretManagerServiceClient()
except Exception as e:
    logger.warning(f"Secret Manager client initialization failed: {e}")
    secret_client = None

try:
    tts_client = texttospeech.TextToSpeechClient()
except Exception as e:
    logger.warning(f"TTS client initialization failed: {e}")
    tts_client = None

try:
    stt_client = speech.SpeechClient()
except Exception as e:
    logger.warning(f"STT client initialization failed: {e}")
    stt_client = None

# Models
class TranslationAudioRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=10000, description="Text to translate")
    source_language: str = Field(..., min_length=2, max_length=10, description="Source language code")
    target_language: str = Field(..., min_length=2, max_length=10, description="Target language code")
    voice_config: dict = Field(
        default={
            "gender": "MALE",
            "style": "NEUTRAL",
            "speaking_rate": 1.0,
            "pitch": 0.0
        },
        description="Voice configuration for TTS"
    )

class TranslationAudioResponse(BaseModel):
    translated_text: str
    source_language: str
    target_language: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    audio_base64: Optional[str] = None
    audio_url: Optional[str] = None
    processing_time_ms: Optional[int] = None

class SpeechToTextRequest(BaseModel):
    audio_base64: str = Field(..., description="Base64 encoded audio")
    language_code: str = Field(..., description="Language code of the audio")
    encoding: str = Field(default="MP3", description="Audio encoding")
    sample_rate: int = Field(default=44100, description="Sample rate")

class TextToSpeechRequest(BaseModel):
    text: str = Field(..., description="Text to convert to speech")
    language_code: str = Field(..., description="Language code for speech")
    voice_gender: str = Field(default="neutral", description="Voice gender")
    speaking_rate: float = Field(default=1.0, ge=0.5, le=2.0)

class HealthResponse(BaseModel):
    status: str
    version: str
    environment: str
    timestamp: str
    services: Dict[str, str]

def get_secret(secret_id: str, project_id: str = None) -> Optional[str]:
    """Retrieve secret from GCP Secret Manager with fallback to environment variables"""
    try:
        # First, try environment variable
        env_var_name = secret_id.upper().replace('-', '_')
        env_value = os.environ.get(env_var_name)
        if env_value:
            logger.info(f"Using environment variable for {secret_id}")
            return env_value.strip()
            
        # If no secret client, return None
        if not secret_client:
            logger.error(f"No secret client available and no environment variable for {secret_id}")
            return None
            
        if not project_id:
            project_id = os.environ.get('GCP_PROJECT', 'universal-translator-prod')
        
        name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
        response = secret_client.access_secret_version(request={"name": name})
        return response.payload.data.decode('UTF-8').strip()
    except Exception as e:
        logger.error(f"Failed to retrieve secret {secret_id}: {e}")
        # Try direct environment variable as last resort
        val = os.environ.get('GEMINI_API_KEY')
        return val.strip() if val else None

class VoiceTranslationService:
    """Service for voice translation with TTS"""
    
    def __init__(self, gemini_api_key: str):
        self.gemini_api_key = gemini_api_key
        # Validate API key looks plausible to avoid invalid metadata errors
        if not gemini_api_key or len(gemini_api_key) < 20:
            raise RuntimeError("Invalid or missing GEMINI_API_KEY")
        genai.configure(api_key=gemini_api_key)
        # Using Gemini 2.5 Flash Preview TTS for cost-effective translations and speech
        self.model = genai.GenerativeModel('gemini-2.5-flash')
        
    async def translate_text(self, text: str, source_lang: str, target_lang: str, voice_config: dict = None) -> Dict[str, Any]:
        """Translate text using Gemini with strict timeout"""
        start_time = time.time()
        logger.info(f"Starting translation: {text[:50]}... ({source_lang} -> {target_lang})")
        logger.info(f"Voice config: {voice_config}")
        try:
            # Create translation prompt
            # Create safety settings and generation config
            safety_settings = [
                {
                    "category": "HARM_CATEGORY_HARASSMENT",
                    "threshold": "BLOCK_NONE"
                },
                {
                    "category": "HARM_CATEGORY_HATE_SPEECH",
                    "threshold": "BLOCK_NONE"
                }
            ]
            
            generation_config = {
                "temperature": 0.1,  # Low temperature for accurate translations
                "top_p": 0.8,
                "top_k": 40,
                "candidate_count": 1
            }
            
            # Create translation prompt
            prompt = f"""
            Translate the following text from {source_lang} to {target_lang}.
            Return ONLY the translated text, no explanations or additional text.
            Make the translation natural and conversational for spoken language.
            
            Text to translate: {text}
            """
            
            # Log the request details
            logger.info(f"Translation request: {text[:50]}... ({source_lang} -> {target_lang})")
            logger.info(f"Using voice settings: {voice_config}")
            # Run blocking generate_content off the event loop with optimized timeout
            import asyncio
            loop = asyncio.get_event_loop()
            response = await asyncio.wait_for(
                loop.run_in_executor(None, lambda: self.model.generate_content(
                    prompt,
                    generation_config=generation_config,
                    safety_settings=safety_settings,
                    stream=False
                )),
                timeout=10.0  # Reduced from 15s to 10s for faster user experience
            )
            
            # Extract translated text
            translated_text = (response.text or "").strip()
            
            # Generate audio using Google Cloud TTS
            audio_data = await self.text_to_speech(
                translated_text,
                target_lang,
                voice_gender="neutral" if not voice_config else voice_config.get("gender", "neutral").lower(),
                speaking_rate=voice_config.get("speaking_rate", 1.0) if voice_config else 1.0
            )
            
            # Convert audio to base64 for transmission
            audio_base64 = base64.b64encode(audio_data).decode('utf-8') if audio_data else None
            
            confidence = 0.95 if translated_text else 0.0
            processing_time = int((time.time() - start_time) * 1000)
            
            return {
                "translated_text": translated_text,
                "audio_base64": audio_base64,
                "confidence": confidence,
                "processing_time_ms": processing_time,
                "audio_format": "mp3"
            }
        except asyncio.TimeoutError:
            logger.warning("Gemini translation timed out")
            raise HTTPException(status_code=408, detail="Translation request timed out")
        except Exception as e:
            logger.error(f"Translation failed: {e}")
            raise HTTPException(status_code=500, detail="Translation failed")
    
    async def text_to_speech(self, text: str, language: str, voice_gender: str = "neutral", speaking_rate: float = 1.0) -> bytes:
        """Convert text to speech using Gemini TTS primary, Google Cloud TTS fallback"""
        # Try Gemini TTS first (primary method)
        try:
            return await self._gemini_tts(text, language, voice_gender, speaking_rate)
        except Exception as e:
            logger.warning(f"Gemini TTS failed, falling back to Google Cloud TTS: {e}")
            return await self._google_cloud_tts(text, language, voice_gender, speaking_rate)
    
    async def _gemini_tts(self, text: str, language: str, voice_gender: str = "neutral", speaking_rate: float = 1.0) -> bytes:
        """Primary TTS using Gemini 2.5 Flash with enhanced voice control"""
        try:
            # Map voice gender to style descriptions
            voice_style_map = {
                "neutral": "professional and clear",
                "male": "confident and warm male voice", 
                "female": "friendly and articulate female voice"
            }
            voice_style = voice_style_map.get(voice_gender, "professional and clear")
            
            # Map language codes to full language names for better Gemini understanding
            language_name_map = {
                "en": "English", "es": "Spanish", "fr": "French", "de": "German",
                "it": "Italian", "pt": "Portuguese", "ru": "Russian", "ja": "Japanese",
                "ko": "Korean", "zh": "Chinese", "ar": "Arabic", "hi": "Hindi"
            }
            language_name = language_name_map.get(language, language)
            
            # Create enhanced prompt for Gemini TTS
            prompt = f"""Convert this text to natural speech in {language_name} with a {voice_style} tone.
            
            Text to convert: {text}
            
            Please generate clear, natural-sounding speech with appropriate pacing and intonation."""
            
            # Configure generation for audio output
            generation_config = {
                "temperature": 0.1,  # Low temperature for consistent voice
                "top_p": 0.8,
                "candidate_count": 1
            }
            
            # Add timeout for Gemini TTS
            import asyncio
            loop = asyncio.get_event_loop()
            response = await asyncio.wait_for(
                loop.run_in_executor(None, lambda: self.model.generate_content(
                    prompt,
                    generation_config=generation_config
                )),
                timeout=6.0  # Optimized timeout for TTS
            )
            
            # Check if response contains audio content
            if hasattr(response, 'audio_content') and response.audio_content:
                logger.info(f"✅ Gemini TTS successful for {language}")
                return response.audio_content
            elif hasattr(response, 'parts') and response.parts:
                # Check if any part contains audio data
                for part in response.parts:
                    if hasattr(part, 'inline_data') and part.inline_data.mime_type.startswith('audio/'):
                        logger.info(f"✅ Gemini TTS successful for {language} (inline data)")
                        return part.inline_data.data
            
            # If no audio content found, raise exception to trigger fallback
            raise Exception("No audio content in Gemini response")
            
        except asyncio.TimeoutError:
            logger.warning(f"Gemini TTS timed out for {language}")
            raise Exception("Gemini TTS timeout")
        except Exception as e:
            logger.warning(f"Gemini TTS failed for {language}: {e}")
            raise e
    
    async def _google_cloud_tts(self, text: str, language: str, voice_gender: str = "neutral", speaking_rate: float = 1.0) -> bytes:
        """Fallback TTS using Google Cloud TTS"""
        try:
            # Check if TTS client is available
            if not tts_client:
                logger.warning("Google Cloud TTS client not available, falling back to gTTS")
                return self._gtts_fallback(text, language)
                
            # Use Google Cloud TTS for reliable fallback
            synthesis_input = texttospeech.SynthesisInput(text=text)
            
            # Select voice parameters
            voice = texttospeech.VoiceSelectionParams(
                language_code=self._get_tts_language_code(language),
                ssml_gender=self._get_voice_gender(voice_gender)
            )
            
            # Select audio configuration
            audio_config = texttospeech.AudioConfig(
                audio_encoding=texttospeech.AudioEncoding.MP3,
                speaking_rate=speaking_rate,
                pitch=0.0
            )
            
            # Add timeout to prevent hanging
            import asyncio
            loop = asyncio.get_event_loop()
            response = await asyncio.wait_for(
                loop.run_in_executor(None, lambda: tts_client.synthesize_speech(
                    input=synthesis_input,
                    voice=voice,
                    audio_config=audio_config
                )),
                timeout=8.0
            )
            
            logger.info(f"✅ Google Cloud TTS fallback successful for {language}")
            return response.audio_content
            
        except asyncio.TimeoutError:
            logger.warning("Google Cloud TTS timed out, falling back to gTTS")
            return self._gtts_fallback(text, language)
        except Exception as e:
            logger.warning(f"Google Cloud TTS failed, falling back to gTTS: {e}")
            # Final fallback to gTTS
            return self._gtts_fallback(text, language)
    
    def _gtts_fallback(self, text: str, language: str) -> bytes:
        """Fallback to gTTS for text-to-speech"""
        try:
            tts = gTTS(text=text, lang=language, slow=False)
            with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as tmp_file:
                tts.save(tmp_file.name)
                with open(tmp_file.name, 'rb') as f:
                    audio_data = f.read()
                os.unlink(tmp_file.name)
                return audio_data
        except Exception as e:
            logger.error(f"gTTS fallback failed: {e}")
            raise HTTPException(status_code=500, detail="Text-to-speech failed")
    
    async def speech_to_text(self, audio_data: bytes, language: str, encoding: str = "MP3", sample_rate: int = 44100) -> str:
        """Convert speech to text using Google Cloud Speech-to-Text"""
        try:
            # Check if STT client is available
            if not stt_client:
                logger.error("STT client not available")
                raise HTTPException(status_code=503, detail="Speech recognition service unavailable")
                
            # Configure audio
            audio = speech.RecognitionAudio(content=audio_data)
            
            # Configure recognition
            config = speech.RecognitionConfig(
                encoding=self._get_audio_encoding(encoding),
                sample_rate_hertz=sample_rate,
                language_code=self._get_stt_language_code(language),
                enable_automatic_punctuation=True,
                model="latest_long"
            )
            
            # Add timeout to prevent hanging
            import asyncio
            loop = asyncio.get_event_loop()
            response = await asyncio.wait_for(
                loop.run_in_executor(None, lambda: stt_client.recognize(config=config, audio=audio)),
                timeout=15.0
            )
            
            # Extract transcription
            transcription = ""
            for result in response.results:
                transcription += result.alternatives[0].transcript + " "
            
            return transcription.strip()
            
        except asyncio.TimeoutError:
            logger.error("Speech-to-text timed out")
            raise HTTPException(status_code=408, detail="Speech recognition timed out")
        except Exception as e:
            logger.error(f"Speech-to-text failed: {e}")
            raise HTTPException(status_code=500, detail="Speech recognition failed")
    
    def _get_tts_language_code(self, lang: str) -> str:
        """Map language code to TTS language code"""
        language_map = {
            "en": "en-US",
            "es": "es-ES",
            "fr": "fr-FR",
            "de": "de-DE",
            "it": "it-IT",
            "pt": "pt-BR",
            "ru": "ru-RU",
            "ja": "ja-JP",
            "ko": "ko-KR",
            "zh": "zh-CN",
            "ar": "ar-XA",
            "hi": "hi-IN"
        }
        return language_map.get(lang, "en-US")
    
    def _get_stt_language_code(self, lang: str) -> str:
        """Map language code to STT language code"""
        return self._get_tts_language_code(lang)  # Same mapping for now
    
    def _get_voice_gender(self, gender: str) -> texttospeech.SsmlVoiceGender:
        """Map voice gender string to enum"""
        gender_map = {
            "male": texttospeech.SsmlVoiceGender.MALE,
            "female": texttospeech.SsmlVoiceGender.FEMALE,
            "neutral": texttospeech.SsmlVoiceGender.NEUTRAL
        }
        return gender_map.get(gender, texttospeech.SsmlVoiceGender.NEUTRAL)
    
    def _get_audio_encoding(self, encoding: str) -> speech.RecognitionConfig.AudioEncoding:
        """Map audio encoding string to enum"""
        encoding_map = {
            "MP3": speech.RecognitionConfig.AudioEncoding.MP3,
            "M4A": speech.RecognitionConfig.AudioEncoding.MP3,
            "WAV": speech.RecognitionConfig.AudioEncoding.LINEAR16
        }
        return encoding_map.get(encoding.upper(), speech.RecognitionConfig.AudioEncoding.MP3)

# Global service instance
translation_service: Optional[VoiceTranslationService] = None

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifecycle management"""
    global translation_service
    
    # Startup
    logger.info("Starting Voice Translation API")
    
    try:
        # Load Gemini API key with multiple fallback options
        gemini_key = get_secret("gemini-api-key")
        if not gemini_key:
            # Try direct environment variable as fallback
            gemini_key = os.environ.get('GEMINI_API_KEY')
            if not gemini_key:
                raise RuntimeError("Failed to load Gemini API key from Secret Manager or environment variables")
        
        # Initialize service
        translation_service = VoiceTranslationService(gemini_key)
        logger.info("Voice translation service initialized")
        
    except Exception as e:
        logger.error(f"Failed to initialize: {e}")
        raise e
    
    yield
    
    # Shutdown
    logger.info("Shutting down Voice Translation API")

# Initialize FastAPI app
app = FastAPI(
    title="Universal Translator Voice API",
    description="Real-time voice translation with audio responses",
    version="2.0.0",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    try:
        services_status = {
            "translation": "healthy" if translation_service else "unhealthy",
            "tts": "healthy" if tts_client else "unavailable",
            "stt": "healthy" if stt_client else "unavailable",
            "secret_manager": "healthy" if secret_client else "unavailable"
        }
        
        return HealthResponse(
            status="healthy" if all(s == "healthy" for s in services_status.values()) else "degraded",
            version="2.0.0",
            environment=os.environ.get("ENVIRONMENT", "production"),
            timestamp=time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
            services=services_status
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(status_code=503, detail="Service unhealthy")

@app.post("/v1/translate/audio", response_model=TranslationAudioResponse)
async def translate_with_audio(request: TranslationAudioRequest):
    """Translate text and return audio of the translation"""
    start_time = time.time()
    
    try:
        if not translation_service:
            raise HTTPException(status_code=503, detail="Service unavailable")
        
        # Translate text with audio
        translation_result = await translation_service.translate_text(
            request.text,
            request.source_language,
            request.target_language,
            request.voice_config
        )
        
        processing_time = int((time.time() - start_time) * 1000)
        
        return TranslationAudioResponse(
            translated_text=translation_result["translated_text"],
            source_language=request.source_language,
            target_language=request.target_language,
            confidence=translation_result["confidence"],
            audio_base64=translation_result["audio_base64"],
            processing_time_ms=processing_time
        )
        
    except HTTPException:
        raise
    except Exception as e:
        error_msg = f"Translation with audio failed: {str(e)}"
        logger.error(error_msg)
        logger.error(f"Full error details: {repr(e)}")
        import traceback
        logger.error(f"Stack trace: {traceback.format_exc()}")
        raise HTTPException(status_code=500, detail=error_msg)

@app.post("/v1/speech-to-text")
async def speech_to_text(request: SpeechToTextRequest):
    """Convert speech to text"""
    try:
        if not translation_service:
            raise HTTPException(status_code=503, detail="Service unavailable")
        
        # Decode audio
        audio_data = base64.b64decode(request.audio_base64)
        
        # Perform STT
        transcription = await translation_service.speech_to_text(
            audio_data,
            request.language_code,
            request.encoding,
            request.sample_rate
        )
        
        return {"transcription": transcription, "language": request.language_code}
        
    except Exception as e:
        logger.error(f"Speech-to-text failed: {e}")
        raise HTTPException(status_code=500, detail="Speech recognition failed")

@app.post("/v1/text-to-speech")
async def text_to_speech(request: TextToSpeechRequest):
    """Convert text to speech"""
    try:
        if not translation_service:
            raise HTTPException(status_code=503, detail="Service unavailable")
        
        # Generate audio
        audio_data = await translation_service.text_to_speech(
            request.text,
            request.language_code,
            request.voice_gender,
            request.speaking_rate
        )
        
        # Return as audio stream
        return StreamingResponse(
            io.BytesIO(audio_data),
            media_type="audio/mpeg",
            headers={"Content-Disposition": "attachment; filename=speech.mp3"}
        )
        
    except Exception as e:
        logger.error(f"Text-to-speech failed: {e}")
        raise HTTPException(status_code=500, detail="Speech synthesis failed")

@app.post("/v1/translate")
async def translate_text(request: TranslationAudioRequest):
    """Legacy text translation endpoint (kept for compatibility)"""
    result = await translate_with_audio(request)
    return {
        "translated_text": result.translated_text,
        "source_language": result.source_language,
        "target_language": result.target_language,
        "confidence": result.confidence,
        "processing_time_ms": result.processing_time_ms
    }

@app.get("/v1/languages")
async def get_supported_languages():
    """Get list of supported languages"""
    return {
        "languages": [
            {"code": "en", "name": "English", "flag": "🇺🇸"},
            {"code": "es", "name": "Spanish", "flag": "🇪🇸"},
            {"code": "fr", "name": "French", "flag": "🇫🇷"},
            {"code": "de", "name": "German", "flag": "🇩🇪"},
            {"code": "it", "name": "Italian", "flag": "🇮🇹"},
            {"code": "pt", "name": "Portuguese", "flag": "🇧🇷"},
            {"code": "ru", "name": "Russian", "flag": "🇷🇺"},
            {"code": "ja", "name": "Japanese", "flag": "🇯🇵"},
            {"code": "ko", "name": "Korean", "flag": "🇰🇷"},
            {"code": "zh", "name": "Chinese", "flag": "🇨🇳"},
            {"code": "ar", "name": "Arabic", "flag": "🇸🇦"},
            {"code": "hi", "name": "Hindi", "flag": "🇮🇳"}
        ]
    }

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Universal Translator Voice API",
        "version": "2.0.0",
        "status": "running",
        "endpoints": {
            "health": "/health",
            "translate_audio": "/v1/translate/audio",
            "speech_to_text": "/v1/speech-to-text",
            "text_to_speech": "/v1/text-to-speech",
            "languages": "/v1/languages",
            "docs": "/docs"
        }
    }

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)