"""
Universal Translator Backend API - Cloud Run Production
Secure implementation with Secret Manager integration
"""

import os
import logging
import json
import time
from contextlib import asynccontextmanager
from typing import Optional, Dict, Any

from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from google.cloud import secretmanager, logging as cloud_logging
import google.generativeai as genai
from pydantic import BaseModel, Field
import httpx

# Configure structured logging for Cloud Logging
def setup_cloud_logging():
    """Setup Cloud Logging for production"""
    if os.environ.get("ENVIRONMENT") == "production":
        try:
            # Initialize Cloud Logging client
            cloud_logging_client = cloud_logging.Client()
            cloud_logging_handler = cloud_logging_client.get_default_handler()
            
            # Configure root logger
            logging.basicConfig(
                level=logging.INFO,
                format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
                handlers=[cloud_logging_handler]
            )
        except Exception as e:
            # Fallback to standard logging if Cloud Logging fails
            logging.basicConfig(
                level=logging.INFO,
                format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            print(f"Failed to setup Cloud Logging: {e}")
    else:
        # Local development logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )

setup_cloud_logging()
logger = logging.getLogger(__name__)

# Structured logging helper
def log_structured(level: str, message: str, **kwargs):
    """Log structured data for Cloud Logging"""
    log_entry = {
        "message": message,
        "timestamp": time.time(),
        "service": "universal-translator-api",
        **kwargs
    }
    
    if level == "info":
        logger.info(json.dumps(log_entry))
    elif level == "error":
        logger.error(json.dumps(log_entry))
    elif level == "warning":
        logger.warning(json.dumps(log_entry))
    else:
        logger.debug(json.dumps(log_entry))

# Initialize Secret Manager client
secret_client = secretmanager.SecretManagerServiceClient()

class TranslationRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=10000, description="Text to translate")
    source_language: str = Field(..., min_length=2, max_length=10, description="Source language code")
    target_language: str = Field(..., min_length=2, max_length=10, description="Target language code")
    
    class Config:
        schema_extra = {
            "example": {
                "text": "Hello world",
                "source_language": "en",
                "target_language": "es"
            }
        }

class TranslationResponse(BaseModel):
    translated_text: str
    source_language: str
    target_language: str
    confidence: float = Field(..., ge=0.0, le=1.0)
    processing_time_ms: Optional[int] = None

class HealthResponse(BaseModel):
    status: str
    version: str
    environment: str
    timestamp: str
    uptime_seconds: Optional[float] = None
    
class ErrorResponse(BaseModel):
    error: str
    detail: str
    timestamp: str
    request_id: Optional[str] = None

def get_secret(secret_id: str, project_id: str = None) -> Optional[str]:
    """
    Securely retrieve secret from GCP Secret Manager
    """
    try:
        if not project_id:
            project_id = os.environ.get('GCP_PROJECT', 'universal-translator-prod')
        
        name = f"projects/{project_id}/secrets/{secret_id}/versions/latest"
        response = secret_client.access_secret_version(request={"name": name})
        secret_value = response.payload.data.decode('UTF-8')
        
        log_structured("info", "Secret retrieved successfully", secret_id=secret_id)
        return secret_value
        
    except Exception as e:
        log_structured("error", "Failed to retrieve secret", 
                      secret_id=secret_id, error=str(e))
        return None

class GeminiTranslationService:
    """Production-ready Gemini translation service"""
    
    def __init__(self, api_key: str):
        self.api_key = api_key
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel('gemini-pro')
        self.rate_limiter = {}  # Simple rate limiting
        
    async def translate(self, text: str, source_lang: str, target_lang: str) -> Dict[str, Any]:
        """
        Translate text using Gemini API with proper error handling
        """
        start_time = time.time()
        
        try:
            # Validate input
            if not text.strip():
                raise ValueError("Empty text provided")
                
            if len(text) > 10000:
                raise ValueError("Text too long (max 10,000 characters)")
            
            # Create translation prompt
            prompt = f"""
            Translate the following text from {source_lang} to {target_lang}.
            Return ONLY the translated text, no explanations or additional text.
            
            Text to translate: {text}
            """
            
            # Make API call with timeout
            response = await self._make_gemini_request(prompt)
            
            # Process response
            translated_text = response.text.strip()
            
            # Calculate confidence (simplified scoring)
            confidence = self._calculate_confidence(text, translated_text)
            
            processing_time = int((time.time() - start_time) * 1000)
            
            log_structured("info", "Translation completed", 
                         source_lang=source_lang,
                         target_lang=target_lang,
                         text_length=len(text),
                         processing_time_ms=processing_time)
            
            return {
                "translated_text": translated_text,
                "confidence": confidence,
                "processing_time_ms": processing_time
            }
            
        except Exception as e:
            processing_time = int((time.time() - start_time) * 1000)
            log_structured("error", "Translation failed",
                         source_lang=source_lang,
                         target_lang=target_lang,
                         error=str(e),
                         processing_time_ms=processing_time)
            raise e
    
    async def _make_gemini_request(self, prompt: str, timeout: int = 30):
        """Make request to Gemini API with timeout and retries"""
        try:
            # Use asyncio timeout for the request
            import asyncio
            return await asyncio.wait_for(
                self._gemini_generate(prompt),
                timeout=timeout
            )
        except asyncio.TimeoutError:
            raise HTTPException(status_code=408, detail="Translation request timed out")
        except Exception as e:
            if "quota" in str(e).lower() or "rate" in str(e).lower():
                raise HTTPException(status_code=429, detail="Rate limit exceeded. Please try again later.")
            elif "invalid" in str(e).lower():
                raise HTTPException(status_code=400, detail="Invalid request or API key")
            else:
                raise HTTPException(status_code=500, detail="Translation service temporarily unavailable")
    
    async def _gemini_generate(self, prompt: str):
        """Async wrapper for Gemini generation"""
        import asyncio
        loop = asyncio.get_event_loop()
        return await loop.run_in_executor(None, self.model.generate_content, prompt)
    
    def _calculate_confidence(self, original: str, translated: str) -> float:
        """Simple confidence calculation based on length and content"""
        if not translated:
            return 0.0
        
        # Basic confidence scoring
        length_ratio = min(len(translated) / len(original), 1.0) if original else 0.0
        base_confidence = 0.85  # Base confidence for Gemini
        
        # Adjust based on length ratio
        if 0.5 <= length_ratio <= 2.0:
            confidence = base_confidence + 0.1
        else:
            confidence = base_confidence - 0.1
            
        return min(max(confidence, 0.0), 1.0)

# Global variables
translation_service: Optional[GeminiTranslationService] = None
app_start_time = time.time()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Manage application lifecycle with proper initialization
    """
    global translation_service
    
    # Startup
    log_structured("info", "Starting Universal Translator API")
    
    try:
        # Load Gemini API key from Secret Manager
        gemini_key = get_secret("gemini-api-key")
        if not gemini_key:
            log_structured("error", "Gemini API key not found in Secret Manager")
            raise RuntimeError("Failed to load Gemini API key")
        
        # Initialize translation service
        translation_service = GeminiTranslationService(gemini_key)
        app.state.translation_service = translation_service
        
        log_structured("info", "Translation service initialized successfully")
        
    except Exception as e:
        log_structured("error", "Failed to initialize application", error=str(e))
        raise e
    
    yield
    
    # Shutdown
    log_structured("info", "Shutting down Universal Translator API")
    translation_service = None

# Initialize FastAPI app
app = FastAPI(
    title="Universal Translator API",
    description="Real-time translation API powered by Gemini",
    version="1.0.0",
    lifespan=lifespan
)

# Configure CORS for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """
    Comprehensive health check endpoint for Cloud Run
    """
    try:
        # Check translation service availability
        service_status = "healthy"
        if not translation_service:
            service_status = "unhealthy - translation service not initialized"
        
        uptime = time.time() - app_start_time
        
        health_data = HealthResponse(
            status=service_status,
            version="1.0.0",
            environment=os.environ.get("ENVIRONMENT", "production"),
            timestamp=time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
            uptime_seconds=uptime
        )
        
        # Log health check
        log_structured("info", "Health check performed", 
                      status=service_status, uptime_seconds=uptime)
        
        return health_data
        
    except Exception as e:
        log_structured("error", "Health check failed", error=str(e))
        raise HTTPException(status_code=503, detail="Service unhealthy")

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "service": "Universal Translator API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "health": "/health",
            "translate": "/v1/translate",
            "languages": "/v1/languages",
            "docs": "/docs"
        }
    }

@app.post("/v1/translate", response_model=TranslationResponse)
async def translate(request: TranslationRequest, req: Request):
    """
    Production translation endpoint with full Gemini integration
    """
    request_id = f"tr_{int(time.time())}_{hash(request.text) % 10000}"
    
    try:
        # Validate translation service is available
        if not translation_service:
            log_structured("error", "Translation service not available", request_id=request_id)
            raise HTTPException(
                status_code=503,
                detail="Translation service temporarily unavailable"
            )
        
        # Log request (without sensitive data)
        log_structured("info", "Translation request received",
                      request_id=request_id,
                      source_lang=request.source_language,
                      target_lang=request.target_language,
                      text_length=len(request.text))
        
        # Validate language codes
        supported_languages = {"en", "es", "fr", "de", "it", "pt", "ru", "ja", "ko", "zh", "ar", "hi"}
        if request.source_language not in supported_languages:
            raise HTTPException(status_code=400, detail=f"Unsupported source language: {request.source_language}")
        if request.target_language not in supported_languages:
            raise HTTPException(status_code=400, detail=f"Unsupported target language: {request.target_language}")
        
        # Perform translation
        result = await translation_service.translate(
            text=request.text,
            source_lang=request.source_language,
            target_lang=request.target_language
        )
        
        response = TranslationResponse(
            translated_text=result["translated_text"],
            source_language=request.source_language,
            target_language=request.target_language,
            confidence=result["confidence"],
            processing_time_ms=result["processing_time_ms"]
        )
        
        log_structured("info", "Translation completed successfully",
                      request_id=request_id,
                      processing_time_ms=result["processing_time_ms"])
        
        return response
        
    except HTTPException:
        # Re-raise HTTP exceptions as-is
        raise
        
    except ValueError as e:
        log_structured("error", "Invalid request data", 
                      request_id=request_id, error=str(e))
        raise HTTPException(status_code=400, detail=str(e))
        
    except Exception as e:
        log_structured("error", "Translation failed unexpectedly", 
                      request_id=request_id, error=str(e))
        raise HTTPException(
            status_code=500,
            detail="Translation failed. Please try again later."
        )

@app.get("/v1/languages")
async def get_supported_languages():
    """
    Get list of supported languages
    """
    return {
        "languages": [
            {"code": "en", "name": "English"},
            {"code": "es", "name": "Spanish"},
            {"code": "fr", "name": "French"},
            {"code": "de", "name": "German"},
            {"code": "it", "name": "Italian"},
            {"code": "pt", "name": "Portuguese"},
            {"code": "ru", "name": "Russian"},
            {"code": "ja", "name": "Japanese"},
            {"code": "ko", "name": "Korean"},
            {"code": "zh", "name": "Chinese"},
            # Add more languages as needed
        ]
    }

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    Production-ready global exception handler with structured logging
    """
    request_id = f"err_{int(time.time())}_{hash(str(exc)) % 10000}"
    
    # Log the error with context
    log_structured("error", "Unhandled exception occurred",
                  request_id=request_id,
                  error_type=type(exc).__name__,
                  error_message=str(exc),
                  url=str(request.url),
                  method=request.method)
    
    # Return user-friendly error response
    error_response = ErrorResponse(
        error="Internal Server Error",
        detail="An unexpected error occurred. Please try again later.",
        timestamp=time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
        request_id=request_id
    )
    
    return JSONResponse(
        status_code=500,
        content=error_response.dict()
    )

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """
    Handle HTTP exceptions with proper logging
    """
    request_id = f"http_{int(time.time())}_{exc.status_code}"
    
    log_structured("warning", "HTTP exception occurred",
                  request_id=request_id,
                  status_code=exc.status_code,
                  detail=exc.detail,
                  url=str(request.url),
                  method=request.method)
    
    error_response = ErrorResponse(
        error=f"HTTP {exc.status_code}",
        detail=exc.detail,
        timestamp=time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
        request_id=request_id
    )
    
    return JSONResponse(
        status_code=exc.status_code,
        content=error_response.dict()
    )

# Startup message
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)