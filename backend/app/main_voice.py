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

# Initialize clients
secret_client = secretmanager.SecretManagerServiceClient()
tts_client = texttospeech.TextToSpeechClient()
stt_client = speech.SpeechClient()

# Models
class TranslationAudioRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=10000, description="Text to translate")
    source_language: str = Field(..., min_length=2, max_length=10, description="Source language code")
    target_language: str = Field(..., min_length=2, max_length=10, description="Target language code")
    return_audio: bool = Field(default=True, description="Return audio of translation")
    voice_gender: str = Field(default="neutral", description="Voice gender: male, female, neutral")
    speaking_rate: float = Field(default=1.0, ge=0.5, le=2.0, description="Speaking rate")

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
    """Retrieve secret from GCP Secret Manager"""
    try:
        if not project_id:
            project_id = os.environ.get('GCP_PROJECT', 'universal-translator-prod')
        
        name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
        response = secret_client.access_secret_version(request={"name": name})
        return response.payload.data.decode('UTF-8')
    except Exception as e:
        logger.error(f"Failed to retrieve secret {secret_id}: {e}")
        return None

class VoiceTranslationService:
    """Service for voice translation with TTS"""
    
    def __init__(self, gemini_api_key: str):
        self.gemini_api_key = gemini_api_key
        genai.configure(api_key=gemini_api_key)
        self.model = genai.GenerativeModel('gemini-1.5-flash')
        
    async def translate_text(self, text: str, source_lang: str, target_lang: str) -> Dict[str, Any]:
        """Translate text using Gemini"""
        start_time = time.time()
        
        try:
            # Create translation prompt
            prompt = f"""
            Translate the following text from {source_lang} to {target_lang}.
            Return ONLY the translated text, no explanations or additional text.
            Make the translation natural and conversational for spoken language.
            
            Text to translate: {text}
            """
            
            # Generate translation
            response = self.model.generate_content(prompt)
            translated_text = response.text.strip()
            
            # Calculate confidence
            confidence = 0.95 if translated_text else 0.0
            
            processing_time = int((time.time() - start_time) * 1000)
            
            return {
                "translated_text": translated_text,
                "confidence": confidence,
                "processing_time_ms": processing_time
            }
            
        except Exception as e:
            logger.error(f"Translation failed: {e}")
            raise HTTPException(status_code=500, detail="Translation failed")
    
    async def text_to_speech(self, text: str, language: str, voice_gender: str = "neutral", speaking_rate: float = 1.0) -> bytes:
        """Convert text to speech using Google Cloud TTS or gTTS"""
        try:
            # Use Google Cloud TTS for better quality
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
            
            # Perform text-to-speech
            response = tts_client.synthesize_speech(
                input=synthesis_input,
                voice=voice,
                audio_config=audio_config
            )
            
            return response.audio_content
            
        except Exception as e:
            logger.warning(f"Google Cloud TTS failed, falling back to gTTS: {e}")
            # Fallback to gTTS
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
            
            # Perform speech recognition
            response = stt_client.recognize(config=config, audio=audio)
            
            # Extract transcription
            transcription = ""
            for result in response.results:
                transcription += result.alternatives[0].transcript + " "
            
            return transcription.strip()
            
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
        # Load Gemini API key
        gemini_key = get_secret("gemini-api-key")
        if not gemini_key:
            raise RuntimeError("Failed to load Gemini API key")
        
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
            "tts": "healthy",
            "stt": "healthy"
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
        
        # Translate text
        translation_result = await translation_service.translate_text(
            request.text,
            request.source_language,
            request.target_language
        )
        
        # Generate audio if requested
        audio_base64 = None
        if request.return_audio:
            audio_data = await translation_service.text_to_speech(
                translation_result["translated_text"],
                request.target_language,
                request.voice_gender,
                request.speaking_rate
            )
            audio_base64 = base64.b64encode(audio_data).decode('utf-8')
        
        processing_time = int((time.time() - start_time) * 1000)
        
        return TranslationAudioResponse(
            translated_text=translation_result["translated_text"],
            source_language=request.source_language,
            target_language=request.target_language,
            confidence=translation_result["confidence"],
            audio_base64=audio_base64,
            processing_time_ms=processing_time
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Translation with audio failed: {e}")
        raise HTTPException(status_code=500, detail="Translation failed")

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
            {"code": "pt", "name": "Portuguese", "flag": "🇵🇹"},
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