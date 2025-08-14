# 🚀 Mervyn Talks - World-Class Development Environment Setup

## 🎯 Overview

This guide establishes a professional development environment with proper branching strategy, automated testing, CI/CD pipelines, and feature development workflows suitable for a production-ready application.

## 🌟 Development Strategy

### Branching Strategy (GitFlow)
```
main              Production-ready code
├── develop       Integration branch for features  
├── feature/*     Individual feature development
├── release/*     Release preparation branches
├── hotfix/*      Critical production fixes
```

### Environment Structure
```
Production    → main branch → Cloud Run (live users)
Staging       → develop branch → Cloud Run staging 
Development   → feature/* → Local/Docker
Testing       → All branches → Automated CI/CD
```

## 🛠️ Branch Setup & Workflows

### 1. Create Development Infrastructure

**Main Development Branch:**
```bash
git checkout -b develop
git push -u origin develop
```

**Feature Development:**
```bash
git checkout develop
git checkout -b feature/[feature-name]
# Example: feature/voice-quality-improvements
```

**Release Preparation:**
```bash
git checkout develop
git checkout -b release/v2.1.0
```

**Hotfixes:**
```bash
git checkout main
git checkout -b hotfix/critical-bug-fix
```

### 2. Branch Protection Rules

**For `main` branch:**
- Require pull request reviews (2 reviewers)
- Require status checks to pass
- Require branches to be up to date
- Require conversation resolution
- Restrict pushes to administrators only

**For `develop` branch:**
- Require pull request reviews (1 reviewer)
- Require status checks to pass
- Allow force pushes for admins

## 🏗️ Local Development Environment

### Prerequisites Installation
```bash
# Install development tools
brew install git node python@3.11 docker
brew install --cask docker visual-studio-code

# Install Firebase CLI
npm install -g firebase-tools

# Install Google Cloud SDK
brew install --cask google-cloud-sdk

# Python development tools
pip3 install --user pipenv black flake8 pytest
```

### Project Setup
```bash
# Clone and setup
git clone https://github.com/delimatsuo/speak-easy-ios.git mervyn-talks-dev
cd mervyn-talks-dev

# Switch to develop branch
git checkout develop

# Setup Python virtual environment
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements_voice.txt
pip install -r requirements-dev.txt  # Development dependencies

# Setup pre-commit hooks
pre-commit install
```

### Environment Configuration
```bash
# Create development environment file
cat > backend/.env.development << EOF
# Development Environment Configuration
ENVIRONMENT=development
GCP_PROJECT=universal-translator-dev
PORT=8080
LOG_LEVEL=DEBUG

# Local development flags
ENABLE_CORS=true
ENABLE_DEBUG_ENDPOINTS=true
SKIP_AUTH_FOR_DEVELOPMENT=true

# Redis (for local development)
REDIS_URL=redis://localhost:6379

# Database (SQLite for local dev)
DATABASE_URL=sqlite:///./dev.db
EOF
```

## 🐳 Docker Development Environment

### Enhanced Docker Compose
```yaml
# docker-compose.dev.yml
version: '3.8'

services:
  # Backend API
  mervyn-talks-api:
    build:
      context: .
      dockerfile: backend/Dockerfile.dev
    ports:
      - "8080:8080"
    environment:
      - ENVIRONMENT=development
      - GCP_PROJECT=universal-translator-dev
    volumes:
      - ./backend:/app
      - ./secrets:/app/secrets:ro
    depends_on:
      - redis
      - postgres
    restart: unless-stopped

  # Redis for caching and rate limiting
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  # PostgreSQL for development database
  postgres:
    image: postgres:15-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: mervyn_talks_dev
      POSTGRES_USER: dev_user
      POSTGRES_PASSWORD: dev_password
    volumes:
      - postgres_data:/var/lib/postgresql/data

  # nginx for local testing
  nginx:
    image: nginx:alpine
    ports:
      - "8000:80"
    volumes:
      - ./config/nginx.dev.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - mervyn-talks-api

  # Testing services
  test-runner:
    build:
      context: .
      dockerfile: backend/Dockerfile.test
    volumes:
      - ./backend:/app
      - ./test-results:/app/test-results
    environment:
      - ENVIRONMENT=testing
    profiles:
      - testing

volumes:
  redis_data:
  postgres_data:
```

### Development Dockerfile
```dockerfile
# backend/Dockerfile.dev
FROM python:3.11-slim

WORKDIR /app

# Install development dependencies
RUN apt-get update && apt-get install -y \
    gcc g++ curl git vim \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements_voice.txt requirements-dev.txt ./
RUN pip install -r requirements_voice.txt -r requirements-dev.txt

# Development tools
RUN pip install debugpy watchdog

# Copy source code
COPY . .

# Development server with hot reload
CMD ["uvicorn", "app.main_voice:app", "--host", "0.0.0.0", "--port", "8080", "--reload"]
```

## 🧪 Testing Infrastructure

### Test Environment Setup
```bash
# Create test requirements
cat > backend/requirements-dev.txt << EOF
# Development and testing dependencies
pytest>=7.4.0
pytest-asyncio>=0.21.0
pytest-cov>=4.1.0
pytest-mock>=3.11.0
httpx>=0.24.0
fakeredis>=2.16.0
factory-boy>=3.3.0
freezegun>=1.2.2

# Code quality
black>=23.7.0
flake8>=6.0.0
isort>=5.12.0
mypy>=1.5.0
pre-commit>=3.3.0

# Security scanning
bandit>=1.7.5
safety>=2.3.0

# Documentation
mkdocs>=1.5.0
mkdocs-material>=9.1.0
EOF
```

### Automated Testing Pipeline
```python
# backend/tests/conftest.py
import pytest
import asyncio
from httpx import AsyncClient
from app.main_voice import app

@pytest.fixture(scope="session")
def event_loop():
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()

@pytest.fixture
async def client():
    """Create test client."""
    async with AsyncClient(app=app, base_url="http://test") as client:
        yield client

@pytest.fixture
def mock_gemini_api(mocker):
    """Mock Gemini API responses."""
    return mocker.patch("app.services.gemini.GeminiTranslationService")
```

### Test Categories Structure
```
backend/tests/
├── unit/                 # Unit tests (fast, isolated)
│   ├── test_translation.py
│   ├── test_security.py
│   └── test_rate_limiting.py
├── integration/          # Integration tests (real dependencies)
│   ├── test_api_endpoints.py
│   ├── test_database.py
│   └── test_external_apis.py
├── e2e/                  # End-to-end tests (full scenarios)
│   ├── test_translation_flow.py
│   └── test_user_journeys.py
├── performance/          # Performance benchmarks
│   ├── test_load.py
│   └── test_memory.py
└── security/             # Security tests
    ├── test_auth.py
    └── test_input_validation.py
```

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow
```yaml
# .github/workflows/development.yml
name: Development CI/CD

on:
  push:
    branches: [develop, feature/*]
  pull_request:
    branches: [develop, main]

env:
  GCP_PROJECT: universal-translator-dev
  REGISTRY: gcr.io

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test_password
          POSTGRES_DB: test_db
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: '3.11'
        
    - name: Cache dependencies
      uses: actions/cache@v3
      with:
        path: ~/.cache/pip
        key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements*.txt') }}
        
    - name: Install dependencies
      run: |
        cd backend
        pip install -r requirements_voice.txt -r requirements-dev.txt
        
    - name: Code quality checks
      run: |
        cd backend
        black --check .
        flake8 .
        isort --check-only .
        mypy .
        
    - name: Security checks
      run: |
        cd backend
        bandit -r . -ll
        safety check
        
    - name: Run unit tests
      run: |
        cd backend
        pytest tests/unit/ -v --cov=app --cov-report=xml
        
    - name: Run integration tests
      run: |
        cd backend
        pytest tests/integration/ -v
        
    - name: Upload coverage
      uses: codecov/codecov-action@v3
      with:
        file: ./backend/coverage.xml

  build:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v1
      with:
        project_id: ${{ env.GCP_PROJECT }}
        service_account_key: ${{ secrets.GCP_SA_KEY }}
        export_default_credentials: true
        
    - name: Build and push Docker image
      run: |
        gcloud builds submit \
          --tag $REGISTRY/$GCP_PROJECT/mervyn-talks-dev:$GITHUB_SHA \
          --timeout=10m \
          backend/
          
    - name: Deploy to Cloud Run (Staging)
      run: |
        gcloud run deploy mervyn-talks-staging \
          --image $REGISTRY/$GCP_PROJECT/mervyn-talks-dev:$GITHUB_SHA \
          --platform managed \
          --region us-central1 \
          --allow-unauthenticated \
          --set-env-vars ENVIRONMENT=staging
```

## 📱 iOS Development Setup

### Xcode Schemes for Environments
```xml
<!-- iOS/UniversalTranslator.xcodeproj/xcschemes/Development.xcscheme -->
<Scheme>
  <BuildAction>
    <BuildActionEntries>
      <BuildActionEntry buildForTesting="YES" buildForRunning="YES">
        <BuildableReference>
          <BlueprintIdentifier>UniversalTranslator</BlueprintIdentifier>
        </BuildableReference>
      </BuildActionEntry>
    </BuildActionEntries>
  </BuildAction>
  <LaunchAction buildConfiguration="Debug">
    <EnvironmentVariables>
      <EnvironmentVariable key="API_BASE_URL" value="http://localhost:8080" isEnabled="YES"/>
      <EnvironmentVariable key="ENVIRONMENT" value="development" isEnabled="YES"/>
      <EnvironmentVariable key="ENABLE_DEBUG_LOGS" value="1" isEnabled="YES"/>
    </EnvironmentVariables>
  </LaunchAction>
</Scheme>
```

### iOS Configuration Management
```swift
// iOS/Sources/Configuration/EnvironmentConfig.swift
import Foundation

enum Environment: String, CaseIterable {
    case development = "development"
    case staging = "staging"
    case production = "production"
    
    static var current: Environment {
        #if DEVELOPMENT
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }
}

struct EnvironmentConfig {
    static var apiBaseURL: String {
        switch Environment.current {
        case .development:
            return ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8080"
        case .staging:
            return "https://mervyn-talks-staging-hash.run.app"
        case .production:
            return "https://universal-translator-prod-hash.run.app"
        }
    }
    
    static var enableDebugLogs: Bool {
        Environment.current == .development
    }
    
    static var enableTestingFeatures: Bool {
        Environment.current != .production
    }
}
```

## 🔧 Development Tools & Scripts

### Development Helper Scripts
```bash
# scripts/dev-setup.sh
#!/bin/bash
set -e

echo "🚀 Setting up Mervyn Talks development environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ Docker required"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "❌ Python 3.11+ required"; exit 1; }

# Setup Python environment
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements_voice.txt -r requirements-dev.txt

# Setup pre-commit hooks
pre-commit install

# Create development database
python -c "
from app.database import create_tables
import asyncio
asyncio.run(create_tables())
"

# Start development services
docker-compose -f ../docker-compose.dev.yml up -d redis postgres

echo "✅ Development environment ready!"
echo "📖 Next steps:"
echo "   1. source backend/.venv/bin/activate"
echo "   2. ./scripts/dev-start.sh"
echo "   3. Open http://localhost:8080/docs"
```

```bash
# scripts/dev-start.sh
#!/bin/bash
set -e

echo "🚀 Starting Mervyn Talks development server..."

cd backend
source .venv/bin/activate

# Load environment variables
export $(cat .env.development | grep -v ^# | xargs)

# Start with hot reload
uvicorn app.main_voice:app \
  --reload \
  --reload-dir app \
  --host 0.0.0.0 \
  --port 8080 \
  --log-level debug

echo "🌐 API running at http://localhost:8080"
echo "📚 Documentation at http://localhost:8080/docs"
```

```bash
# scripts/test-all.sh
#!/bin/bash
set -e

cd backend
source .venv/bin/activate

echo "🧪 Running all tests..."

# Code quality
echo "📝 Code quality checks..."
black --check .
flake8 .
isort --check-only .
mypy .

# Security
echo "🔒 Security checks..."
bandit -r . -ll
safety check

# Tests
echo "🎯 Unit tests..."
pytest tests/unit/ -v --cov=app

echo "🔗 Integration tests..."
pytest tests/integration/ -v

echo "🚀 E2E tests..."
pytest tests/e2e/ -v

echo "✅ All tests passed!"
```

## 📊 Monitoring & Observability

### Development Monitoring Stack
```yaml
# docker-compose.monitoring.yml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml
      
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
      
  jaeger:
    image: jaegertracing/all-in-one:latest
    ports:
      - "16686:16686"
      - "14268:14268"
    environment:
      - COLLECTOR_OTLP_ENABLED=true

volumes:
  grafana_data:
```

### Application Metrics
```python
# backend/app/monitoring.py
from prometheus_client import Counter, Histogram, generate_latest
import time
import functools

# Metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration')
TRANSLATION_COUNT = Counter('translations_total', 'Total translations', ['source_lang', 'target_lang'])

def track_performance(func):
    @functools.wraps(func)
    async def wrapper(*args, **kwargs):
        start_time = time.time()
        try:
            result = await func(*args, **kwargs)
            return result
        finally:
            REQUEST_DURATION.observe(time.time() - start_time)
    return wrapper
```

## 🔐 Security & Secrets Management

### Development Secrets
```bash
# scripts/setup-secrets.sh
#!/bin/bash

# Create secrets directory
mkdir -p secrets

# Development secrets (DO NOT commit these)
cat > secrets/.env.secrets << EOF
# Development secrets - DO NOT COMMIT
GEMINI_API_KEY=your-development-key-here
JWT_SECRET=development-jwt-secret-key
DATABASE_PASSWORD=development-db-password
REDIS_PASSWORD=development-redis-password
EOF

# Add to .gitignore
echo "secrets/" >> .gitignore
echo ".env.secrets" >> .gitignore

echo "🔐 Secrets configured for development"
echo "⚠️  Remember to set real secrets in production!"
```

### Pre-commit Hooks
```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-merge-conflict
      - id: check-added-large-files
      
  - repo: https://github.com/psf/black
    rev: 23.7.0
    hooks:
      - id: black
        
  - repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
      - id: isort
        
  - repo: https://github.com/pycqa/flake8
    rev: 6.0.0
    hooks:
      - id: flake8
        
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.5.0
    hooks:
      - id: mypy
        
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
```

## 📈 Performance Testing

### Load Testing Setup
```python
# backend/tests/performance/test_load.py
import asyncio
import aiohttp
import pytest
from statistics import mean, median

@pytest.mark.performance
async def test_translation_endpoint_load():
    """Test translation endpoint under load."""
    
    async def make_request(session, url, payload):
        async with session.post(url, json=payload) as response:
            return response.status, await response.json()
    
    url = "http://localhost:8080/v1/translate"
    payload = {
        "text": "Hello world",
        "source_language": "en", 
        "target_language": "es"
    }
    
    # Simulate 100 concurrent requests
    async with aiohttp.ClientSession() as session:
        tasks = [make_request(session, url, payload) for _ in range(100)]
        
        start_time = asyncio.get_event_loop().time()
        results = await asyncio.gather(*tasks)
        end_time = asyncio.get_event_loop().time()
        
        # Analyze results
        successful = sum(1 for status, _ in results if status == 200)
        total_time = end_time - start_time
        
        assert successful >= 95, f"Success rate too low: {successful}/100"
        assert total_time < 30, f"Total time too high: {total_time}s"
        
        print(f"✅ Load test: {successful}/100 successful in {total_time:.2f}s")
```

## 🚀 Quick Start Commands

### Initial Setup
```bash
# Clone and setup development environment
git clone https://github.com/delimatsuo/speak-easy-ios.git mervyn-talks-dev
cd mervyn-talks-dev
./scripts/dev-setup.sh
```

### Daily Development Workflow
```bash
# Start development environment
./scripts/dev-start.sh

# In another terminal: run tests
./scripts/test-all.sh

# Create new feature
git checkout develop
git pull origin develop
git checkout -b feature/my-new-feature

# After development: create PR
git push -u origin feature/my-new-feature
# Create PR from feature/my-new-feature → develop
```

### Feature Development Cycle
```bash
# 1. Start feature
git checkout develop && git pull
git checkout -b feature/voice-quality-improvements

# 2. Develop with live reload
./scripts/dev-start.sh

# 3. Test continuously  
./scripts/test-all.sh

# 4. Commit and push
git add . && git commit -m "feat: improve voice quality algorithm"
git push -u origin feature/voice-quality-improvements

# 5. Create PR → develop branch
# 6. After review merge → triggers staging deployment
# 7. After testing → merge develop → main (production)
```

This world-class development environment provides:

1. **Professional branching strategy** with GitFlow
2. **Automated testing pipeline** with comprehensive coverage
3. **Containerized development** with Docker Compose  
4. **CI/CD integration** with GitHub Actions
5. **Security scanning** and secret management
6. **Performance monitoring** and load testing
7. **Code quality enforcement** with pre-commit hooks
8. **Environment-specific configuration** for dev/staging/prod

Ready to implement this setup?
