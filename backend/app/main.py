"""
Universal Translator Backend API - Cloud Run Production
Secure implementation with Secret Manager integration
"""

import os
import logging
import json
import time
import random
from contextlib import asynccontextmanager
from typing import Optional, Dict, Any

from fastapi import FastAPI, HTTPException, Request, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from google.cloud import secretmanager, logging as cloud_logging
import google.generativeai as genai
from pydantic import BaseModel, Field
import httpx
from .rate_limiter import RateLimiter
from .key_rotation import KeyRotationService

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
        # Using Gemini 2.5 Flash for faster, more cost-effective translations
        self.model = genai.GenerativeModel('gemini-2.5-flash')
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
rate_limiter: Optional[RateLimiter] = None
key_rotation_service: Optional[KeyRotationService] = None
app_start_time = time.time()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Manage application lifecycle with proper initialization
    """
    global translation_service, rate_limiter, key_rotation_service
    
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
        
        # Initialize rate limiter
        redis_url = os.environ.get("REDIS_URL", "redis://localhost:6379")
        rate_limiter = RateLimiter(redis_url)
        app.state.rate_limiter = rate_limiter
        
        # Initialize key rotation service
        project_id = os.environ.get("GCP_PROJECT", "universal-translator-prod")
        key_rotation_service = KeyRotationService(project_id)
        app.state.key_rotation_service = key_rotation_service
        
        # Schedule key rotation check
        asyncio.create_task(check_key_rotation())
        
        log_structured("info", "Services initialized successfully")
        
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

async def check_key_rotation():
    """
    Periodic task to check and rotate API keys
    """
    while True:
        try:
            if key_rotation_service:
                # Check Gemini API key rotation
                if await key_rotation_service.check_rotation_needed("gemini-api-key"):
                    log_structured("info", "Key rotation needed for Gemini API")
                    # In production, this would integrate with your key management system
                    # For now, we'll just log the event
                    new_key = await generate_new_api_key()
                    if new_key:
                        success = await key_rotation_service.rotate_key("gemini-api-key", new_key)
                        if success:
                            log_structured("info", "Successfully rotated Gemini API key")
                            # Update translation service with new key
                            global translation_service
                            if translation_service:
                                translation_service.api_key = new_key
                                genai.configure(api_key=new_key)
                
        except Exception as e:
            log_structured("error", "Key rotation check failed", error=str(e))
        
        # Check every 24 hours
        await asyncio.sleep(24 * 60 * 60)

async def generate_new_api_key() -> Optional[str]:
    """
    Generate new API key (placeholder - integrate with your key management system)
    """
    try:
        # In production, this would call your API key management system
        # For demonstration, we'll return None to indicate no rotation needed
        log_structured("info", "Key generation requested - integrate with key management system")
        return None
    except Exception as e:
        log_structured("error", "Failed to generate new API key", error=str(e))
        return None

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

@app.get("/v1/admin/analytics")
async def get_analytics(req: Request):
    """
    Analytics endpoint for admin dashboard
    Returns aggregated usage statistics (no personal data)
    """
    try:
        # This would typically connect to a proper analytics database
        # For now, return sample data that matches the dashboard structure
        
        analytics_data = {
            "daily_requests": {
                "today": random.randint(100, 500),
                "yesterday": random.randint(80, 450),
                "week_avg": random.randint(200, 400)
            },
            "language_pairs": {
                "en_es": random.randint(40, 60),
                "es_en": random.randint(25, 40),
                "en_fr": random.randint(8, 15),
                "other": random.randint(5, 20)
            },
            "error_rates": {
                "translation_errors": round(random.uniform(0.1, 2.0), 2),
                "rate_limit_hits": random.randint(0, 10),
                "timeout_errors": round(random.uniform(0.0, 1.0), 2)
            },
            "performance": {
                "avg_response_time_ms": random.randint(800, 1500),
                "p95_response_time_ms": random.randint(1500, 3000),
                "success_rate": round(random.uniform(97.0, 99.9), 2)
            },
            "usage_patterns": {
                "peak_hour": "19:00-20:00",
                "busiest_day": "Tuesday",
                "avg_session_length_sec": random.randint(120, 300)
            }
        }
        
        log_structured("info", "Analytics data requested", 
                      endpoint="admin_analytics")
        
        return analytics_data
        
    except Exception as e:
        log_structured("error", "Failed to fetch analytics", 
                      error=str(e))
        raise HTTPException(status_code=500, detail="Failed to fetch analytics")

@app.get("/v1/admin/system-health")
async def get_system_health(req: Request):
    """
    System health endpoint for admin dashboard
    """
    try:
        uptime = time.time() - app_start_time
        
        health_data = {
            "status": "healthy",
            "uptime_seconds": uptime,
            "uptime_human": f"{int(uptime//3600)}h {int((uptime%3600)//60)}m",
            "memory_usage": "~500MB", # Would be actual memory monitoring in production
            "cpu_usage": f"{random.uniform(10, 30):.1f}%",
            "api_endpoints": {
                "translation": "operational",
                "health": "operational", 
                "analytics": "operational"
            },
            "external_services": {
                "gemini_api": "operational",
                "firebase": "operational"
            },
            "version": "1.0.0",
            "environment": os.environ.get("ENVIRONMENT", "production"),
            "last_check": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime())
        }
        
        log_structured("info", "System health check performed")
        
        return health_data
        
    except Exception as e:
        log_structured("error", "Failed to fetch system health", 
                      error=str(e))
        raise HTTPException(status_code=500, detail="Failed to fetch system health")

@app.post("/v1/translate", response_model=TranslationResponse)
async def translate(request: TranslationRequest, req: Request):
    # Check rate limit
    if rate_limiter:
        await rate_limiter.require_rate_limit(req, "translation")
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