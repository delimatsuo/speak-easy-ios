# 🤖 AI Agent Onboarding Guide - Mervyn Talks Project

## 📋 **REQUIRED READING FOR NEW AI CODING AGENTS**

**Welcome to the Mervyn Talks project!** This guide will bring you up to speed on our codebase, architecture, and development practices. Please read this document first before making any code changes.

---

## 🎯 **Project Overview**

### **What is Mervyn Talks?**
Mervyn Talks is a real-time voice translation app designed for travelers and expats. Users can speak in one language and get instant translation with audio output in another language. Think Google Translate but optimized for conversations and travel scenarios.

### **Core Functionality**
- **Voice Input**: Record speech in source language
- **Real-time Translation**: Powered by Google Gemini API
- **Voice Output**: Text-to-speech in target language
- **Credit System**: Users purchase minutes for translation services
- **12 Languages**: English, Spanish, French, German, Italian, Portuguese, Russian, Japanese, Korean, Chinese, Arabic, Hindi

### **Target Users**
- International travelers (business & leisure)
- Expats living abroad
- Digital nomads working worldwide
- Study abroad students

---

## 🏗️ **Architecture Overview**

### **Technology Stack**
```
📱 Frontend: iOS (Swift/SwiftUI)
🔗 Backend: Python (FastAPI)
🧠 AI: Google Gemini 2.5 Flash + TTS
☁️ Cloud: Google Cloud Platform
🗄️ Database: PostgreSQL + Redis
🐳 Development: Docker + Docker Compose
🚀 Deployment: Cloud Run
🔄 CI/CD: GitHub Actions
```

### **Key Components**
```
iOS App (Swift/SwiftUI)
├── Voice Recording & Playback
├── Real-time UI Updates
├── Credit Management
└── User Authentication (Apple/Google)

Backend API (Python/FastAPI)
├── Translation Service (Gemini)
├── TTS Service (Gemini TTS)
├── Rate Limiting (Redis)
├── User Management (PostgreSQL)
├── Credit System (Firestore)
└── Analytics & Monitoring

Infrastructure
├── Cloud Run (Backend hosting)
├── Firebase (Auth, Firestore, Hosting)
├── Redis Memorystore (Caching)
├── Secret Manager (API keys)
└── Admin Dashboard (Firebase Hosting)
```

---

## 📁 **Project Structure**

### **Repository Layout**
```
UniversalTranslatorApp/
├── 📱 iOS/                          # iOS application
│   ├── Sources/                     # Swift source code
│   ├── Resources/                   # Assets, configs, localizations
│   ├── Documentation/               # iOS-specific docs
│   └── Tools/                       # Build scripts, utilities
├── 🔗 backend/                      # Backend API
│   ├── app/                         # FastAPI application
│   ├── tests/                       # Comprehensive test suite
│   └── scripts/                     # Deployment & utility scripts
├── 📊 admin/                        # Admin dashboard
├── 🎯 marketing/                    # Marketing materials & strategy
├── 🐳 config/                       # Configuration files
├── 📋 docs/                         # Project documentation
├── ⚙️ scripts/                      # Development helper scripts
└── 🧪 tests/                        # Integration tests
```

### **Key Files to Understand**
| File | Purpose | When to Read |
|------|---------|--------------|
| `DEV_ENVIRONMENT_SETUP.md` | Complete dev setup guide | Setting up development |
| `DEVELOPMENT_QUICK_START.md` | Immediate development workflow | Starting development |
| `MARKETING_STRATEGY.md` | Go-to-market strategy | Understanding business |
| `ADMIN_DASHBOARD_GUIDE.md` | Admin features & usage | Backend/admin work |
| `backend/app/main_voice.py` | Main API endpoints | Backend development |
| `iOS/Sources/App/UniversalTranslatorApp.swift` | iOS app entry point | iOS development |
| `docker-compose.dev.yml` | Development environment | Local development |
| `.github/workflows/development.yml` | CI/CD pipeline | Deployment work |

---

## 🌿 **Git Workflow (GitFlow)**

### **Branch Strategy**
```
main                    ← Production (protected, auto-deploys)
├── develop            ← Integration branch (auto-deploys to staging)
├── feature/*          ← Feature development
├── release/*          ← Release preparation
└── hotfix/*           ← Critical production fixes
```

### **Development Workflow**
```bash
# 1. Start new feature
git checkout develop
git pull origin develop
git checkout -b feature/your-feature-name

# 2. Develop & test
./scripts/dev-start.sh        # Start development server
./scripts/test-all.sh         # Run all tests

# 3. Commit & push
git add .
git commit -m "feat: your feature description"
git push -u origin feature/your-feature-name

# 4. Create PR: feature/your-feature-name → develop
# 5. After review merge → automatic staging deployment
# 6. After testing → merge develop → main (production)
```

### **Commit Convention**
```
feat: new feature
fix: bug fix
docs: documentation
test: testing
refactor: code refactoring
perf: performance improvement
security: security enhancement
ci: CI/CD changes
```

---

## 🧪 **Testing Strategy**

### **Test Structure**
```
backend/tests/
├── unit/           # Fast, isolated tests (90% coverage target)
├── integration/    # Database, Redis, APIs (80% coverage target)
├── e2e/           # Complete user workflows
├── performance/   # Load testing, benchmarks (<2s response time)
└── security/      # Security validation
```

### **Running Tests**
```bash
# All tests
./scripts/test-all.sh

# Specific categories
cd backend && source .venv/bin/activate
pytest tests/unit/ -v              # Unit tests
pytest tests/integration/ -v       # Integration tests
pytest tests/e2e/ -v              # End-to-end tests
pytest tests/performance/ -v       # Performance tests

# With coverage
pytest --cov=app --cov-report=html
```

### **Quality Gates**
- ✅ **Code formatting** (black, isort)
- ✅ **Linting** (flake8, mypy)
- ✅ **Security scanning** (bandit, safety)
- ✅ **Unit tests** (90%+ coverage)
- ✅ **Integration tests** (80%+ coverage)
- ✅ **Performance tests** (<2s response time)

---

## 🔧 **Development Environment**

### **Quick Setup**
```bash
# 1. One-time setup
./scripts/dev-setup.sh

# 2. Add API keys
cp secrets/.env.secrets.template secrets/.env.secrets
# Edit with your Gemini API key

# 3. Start development
./scripts/dev-start.sh

# Your API will be available at:
# 🌐 http://localhost:8080
# 📚 http://localhost:8080/docs
```

### **Development Services**
| Service | URL | Purpose |
|---------|-----|---------|
| Backend API | http://localhost:8080 | Main API |
| API Docs | http://localhost:8080/docs | Swagger UI |
| Admin Dashboard | http://localhost:8080/admin | User management |
| nginx Proxy | http://localhost:8000 | Load balancer |
| Prometheus | http://localhost:9090 | Metrics |
| Grafana | http://localhost:3000 | Dashboards (admin/admin) |

### **Key Environment Variables**
```bash
# Required for development
GEMINI_API_KEY=your-api-key-here
ENVIRONMENT=development
GCP_PROJECT=universal-translator-dev

# Database
DATABASE_URL=postgresql://dev_user:dev_password@localhost:5432/mervyn_talks_dev
REDIS_URL=redis://localhost:6379

# Features
ENABLE_DEBUG_ENDPOINTS=true
ENABLE_CORS=true
LOG_LEVEL=DEBUG
```

---

## 🔍 **Key APIs & Services**

### **Main API Endpoints**
```python
# Translation
POST /v1/translate
{
  "text": "Hello world",
  "source_language": "en",
  "target_language": "es",
  "include_audio": true,
  "voice": "neutral"
}

# Health check
GET /health

# Language support
GET /v1/languages

# Admin analytics
GET /v1/admin/analytics
GET /v1/admin/system-health
```

### **Backend Services**
```python
# Core services (backend/app/)
├── services/
│   ├── translation.py          # Gemini translation service
│   ├── tts.py                  # Text-to-speech service
│   └── audio.py                # Audio processing
├── managers/
│   ├── rate_limiter.py         # Rate limiting (Redis)
│   ├── key_rotation.py         # API key rotation
│   └── cache.py                # Caching layer
└── models/
    ├── translation.py          # Translation models
    └── user.py                 # User models
```

### **iOS App Structure**
```swift
// iOS/Sources/
├── App/                        # App lifecycle
├── Views/                      # SwiftUI views
├── Components/                 # Reusable UI components
├── Services/                   # API services
├── Managers/                   # Business logic
├── Utilities/                  # Helper functions
└── Configuration/              # Environment config
```

---

## 🔐 **Security & Best Practices**

### **Security Requirements**
- ✅ **No secrets in code** - Use `secrets/.env.secrets`
- ✅ **Input validation** - Validate all user inputs
- ✅ **Rate limiting** - Protect against abuse
- ✅ **Certificate pinning** - Production TLS security
- ✅ **Security scanning** - Pre-commit hooks
- ✅ **Audit logging** - Track security events

### **Code Quality Standards**
```python
# Python formatting
black .                         # Code formatting
isort .                         # Import sorting
flake8 .                        # Linting
mypy .                          # Type checking
bandit -r . -ll                 # Security scanning
```

### **Performance Requirements**
- **API Response Time**: < 2 seconds
- **Memory Usage**: < 512MB per container
- **Database Queries**: Use indexes, avoid N+1
- **Caching**: Cache expensive operations

---

## 📊 **Business Logic**

### **Credit System**
```python
# Users purchase translation minutes
CreditProduct.seconds300 = "com.mervyntalks.credits.300s"  # 5 minutes
CreditProduct.seconds600 = "com.mervyntalks.credits.600s"  # 10 minutes

# Credits stored in Firebase Firestore
# Deducted based on translation duration
# Managed via CreditsManager (iOS) and backend APIs
```

### **User Flow**
```
1. User opens app
2. Apple/Google Sign In (optional for free trial)
3. Select source and target languages
4. Record voice → transcription
5. Translation via Gemini API
6. Text-to-speech → audio output
7. Credits deducted based on usage
8. Purchase more credits via StoreKit
```

### **Supported Languages**
```python
SUPPORTED_LANGUAGES = {
    "en": "English", "es": "Spanish", "fr": "French",
    "de": "German", "it": "Italian", "pt": "Portuguese", 
    "ru": "Russian", "ja": "Japanese", "ko": "Korean",
    "zh": "Chinese", "ar": "Arabic", "hi": "Hindi"
}
```

---

## 🚀 **Deployment & Infrastructure**

### **Environments**
- **Development**: Local Docker environment
- **Staging**: Cloud Run (auto-deployed from `develop`)
- **Production**: Cloud Run (auto-deployed from `main`)

### **CI/CD Pipeline**
```yaml
# Triggered on pull requests and pushes
1. Code quality checks (formatting, linting, security)
2. Unit and integration tests
3. Build Docker images
4. Deploy to staging (develop branch)
5. Run E2E tests against staging
6. Deploy to production (main branch)
7. Run smoke tests and monitoring
```

### **Monitoring Stack**
- **Prometheus**: Metrics collection
- **Grafana**: Dashboards and alerting  
- **Jaeger**: Distributed tracing
- **Cloud Logging**: Centralized logs
- **Admin Dashboard**: User analytics

---

## 📚 **Common Development Tasks**

### **Adding a New API Endpoint**
```python
# 1. Add route to backend/app/main_voice.py
@app.post("/v1/new-endpoint")
async def new_endpoint(request: NewRequest):
    # Implementation
    return {"result": "success"}

# 2. Add request/response models
class NewRequest(BaseModel):
    field: str

# 3. Add tests
# backend/tests/unit/test_new_endpoint.py
# backend/tests/integration/test_new_endpoint.py

# 4. Update API documentation (automatic via FastAPI)
```

### **Adding iOS Features**
```swift
// 1. Create new view
// iOS/Sources/Views/NewFeatureView.swift

// 2. Add to navigation
// Update ContentView.swift or appropriate parent

// 3. Add any required services
// iOS/Sources/Services/NewFeatureService.swift

// 4. Add tests (if applicable)
// iOS/Tests/NewFeatureTests.swift
```

### **Database Changes**
```python
# 1. Update models in backend/app/models/
# 2. Create migration script
# 3. Update test fixtures
# 4. Run tests to ensure compatibility
```

---

## ⚠️ **Important Notes & Gotchas**

### **Things to Remember**
1. **API Keys**: Never commit API keys. Use `secrets/.env.secrets`
2. **Testing**: Always run `./scripts/test-all.sh` before pushing
3. **Dependencies**: Update both `requirements_voice.txt` and `requirements-dev.txt`
4. **iOS Schemes**: Use Development scheme for local testing
5. **Rate Limits**: Gemini API has 60 RPM limit - handle gracefully
6. **Credits**: Credit deduction happens server-side for security

### **Common Issues**
```bash
# Services won't start
docker-compose -f docker-compose.dev.yml down
docker system prune -f
docker-compose -f docker-compose.dev.yml up -d

# Python environment issues
cd backend && rm -rf .venv
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements_voice.txt -r requirements-dev.txt

# Tests failing
export ENVIRONMENT=testing
export DATABASE_URL="postgresql://dev_user:dev_password@localhost:5432/mervyn_talks_test"
export REDIS_URL="redis://localhost:6379"
```

### **Performance Considerations**
- **Translation Caching**: Translations are cached in Redis for 30 minutes
- **Audio Caching**: TTS output cached to reduce API calls
- **Database Connections**: Use connection pooling
- **Memory Management**: iOS app clears conversation on background

---

## 🎯 **Development Priorities**

### **Current Status**
- ✅ **Core MVP**: Complete and production-ready
- ✅ **Admin Dashboard**: Full analytics and user management
- ✅ **Marketing Strategy**: Complete go-to-market plan
- ✅ **Development Infrastructure**: World-class setup
- 🔄 **Active Development**: New features and optimizations

### **Next Development Areas**
1. **Performance Optimization**: Response time improvements
2. **New Features**: User-requested functionality
3. **Language Expansion**: Additional language support
4. **Platform Expansion**: Android app development
5. **Enterprise Features**: Team accounts, bulk pricing

---

## 🤝 **How to Contribute Effectively**

### **Before Making Changes**
1. **Read this document completely**
2. **Review relevant documentation** (see "Key Files" section)
3. **Set up development environment** (`./scripts/dev-setup.sh`)
4. **Run existing tests** to ensure setup works
5. **Understand the specific area** you'll be working on

### **Development Best Practices**
1. **Follow GitFlow workflow** - Always branch from `develop`
2. **Write tests first** - TDD approach encouraged
3. **Run quality checks** - Pre-commit hooks will enforce
4. **Document changes** - Update relevant docs
5. **Test thoroughly** - Unit, integration, and manual testing

### **Communication**
- **Ask questions** about unclear requirements
- **Propose solutions** before implementing large changes
- **Document decisions** in code comments and commit messages
- **Consider performance** and security implications

---

## 📖 **Essential Reading List**

### **Must Read (in order)**
1. **This document** (`AI_AGENT_ONBOARDING.md`) - Overview and onboarding
2. **`DEVELOPMENT_QUICK_START.md`** - Immediate development workflow
3. **`DEV_ENVIRONMENT_SETUP.md`** - Complete development setup
4. **`backend/app/main_voice.py`** - Main API implementation
5. **`iOS/Sources/Configuration/EnvironmentConfig.swift`** - iOS environments

### **Additional Documentation**
- **`MARKETING_STRATEGY.md`** - Business context and user needs
- **`ADMIN_DASHBOARD_GUIDE.md`** - Admin features and user management
- **`SECURITY_IMPLEMENTATION_REPORT.md`** - Security architecture
- **`backend/tests/conftest.py`** - Testing framework and fixtures
- **`docker-compose.dev.yml`** - Development environment services

### **API Documentation**
- **http://localhost:8080/docs** - Interactive API documentation
- **http://localhost:8080/redoc** - Alternative API documentation

---

## 🎉 **Welcome to the Team!**

You're now ready to contribute to Mervyn Talks! This project has:

🚀 **Professional development infrastructure**  
🧪 **Comprehensive testing framework**  
🔐 **Enterprise-level security**  
📊 **Full monitoring and analytics**  
📱 **Production-ready iOS and backend**  
🌍 **Global user base ready for scaling**  

**Happy coding! Let's build amazing translation features together!** 🗣️✨

---

*This document is maintained and updated as the project evolves. If you notice anything outdated or missing, please update it as part of your contribution.*
