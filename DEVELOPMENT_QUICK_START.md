# 🚀 Mervyn Talks - Development Quick Start Guide

## 🎯 Ready to Start Developing!

Your world-class development environment is now set up and ready. Here's how to get started immediately:

## 🌟 Branch Structure (GitFlow)

```
main                    ← Production (protected)
├── develop            ← Integration branch ✅ CREATED
├── feature/*          ← Feature development
├── release/*          ← Release preparation  
└── hotfix/*           ← Critical fixes
```

## ⚡ Quick Start Commands

### 1. Set Up Your Development Environment
```bash
# Run the automated setup (one-time only)
./scripts/dev-setup.sh

# This will:
# ✅ Install all dependencies
# ✅ Create Python virtual environment
# ✅ Set up Docker services
# ✅ Configure development environment
# ✅ Create helper scripts
```

### 2. Start Development Server
```bash
# Option A: Native Python (fastest for development)
./scripts/dev-start.sh

# Option B: Full Docker environment
./scripts/dev-docker.sh

# Your API will be available at:
# 🌐 http://localhost:8080
# 📚 http://localhost:8080/docs (API documentation)
```

### 3. Create a New Feature
```bash
# Start from develop branch
git checkout develop
git pull origin develop

# Create your feature branch
git checkout -b feature/your-amazing-feature

# Start coding!
```

### 4. Test Your Code
```bash
# Run all tests
./scripts/test-all.sh

# This runs:
# ✅ Code quality checks (black, flake8, isort)
# ✅ Security scans (bandit, safety)
# ✅ Unit tests with coverage
# ✅ Integration tests
```

## 🎮 Development Workflow Example

Let's create a sample feature to show you the complete workflow:

### Example: Add Translation History Feature

```bash
# 1. Create feature branch
git checkout develop
git checkout -b feature/translation-history

# 2. Start development server
./scripts/dev-start.sh

# 3. Add your code (example)
# Create: backend/app/routes/history.py
# Create: backend/tests/unit/test_history.py
# Update: backend/app/main_voice.py

# 4. Test your changes
./scripts/test-all.sh

# 5. Commit your changes
git add .
git commit -m "feat: add translation history endpoint

- Add GET /v1/history endpoint
- Add user translation history storage
- Add pagination and filtering
- Include comprehensive tests"

# 6. Push and create PR
git push -u origin feature/translation-history
# Create PR: feature/translation-history → develop
```

## 🌐 Available Development URLs

When your development environment is running:

| Service | URL | Description |
|---------|-----|-------------|
| **API** | http://localhost:8080 | Main backend API |
| **API Docs** | http://localhost:8080/docs | Interactive API documentation |
| **Admin Dashboard** | http://localhost:8080/admin | Admin interface |
| **nginx Proxy** | http://localhost:8000 | Load balanced proxy |
| **Prometheus** | http://localhost:9090 | Metrics (with monitoring profile) |
| **Grafana** | http://localhost:3000 | Dashboards (admin/admin) |
| **Jaeger** | http://localhost:16686 | Distributed tracing |

## 🛠️ Development Commands Reference

### Environment Management
```bash
# Setup development environment
./scripts/dev-setup.sh

# Start development server
./scripts/dev-start.sh

# Start full Docker environment
./scripts/dev-docker.sh

# Stop all services
docker-compose -f docker-compose.dev.yml down
```

### Testing Commands
```bash
# Run all tests
./scripts/test-all.sh

# Run specific test categories
cd backend && source .venv/bin/activate
pytest tests/unit/ -v              # Unit tests
pytest tests/integration/ -v       # Integration tests
pytest tests/e2e/ -v              # End-to-end tests
pytest tests/performance/ -v       # Performance tests
pytest tests/security/ -v          # Security tests

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/unit/test_translation_service.py -v
```

### Code Quality
```bash
cd backend && source .venv/bin/activate

# Format code
black .
isort .

# Lint code
flake8 .
mypy .

# Security check
bandit -r . -ll
safety check
```

### Git Workflow
```bash
# Feature development
git checkout develop
git pull origin develop
git checkout -b feature/my-feature
# ... make changes ...
git add .
git commit -m "feat: description"
git push -u origin feature/my-feature

# Create PR: feature/my-feature → develop

# After PR merged, cleanup
git checkout develop
git pull origin develop
git branch -d feature/my-feature
```

## 🔧 Configuration Files

### Development Secrets
```bash
# Copy template and fill in your API keys
cp secrets/.env.secrets.template secrets/.env.secrets

# Edit with your actual keys:
# - GEMINI_API_KEY (from https://makersuite.google.com/app/apikey)
# - Other required secrets
```

### Environment Variables
Key development settings in `backend/.env.development`:
- `ENVIRONMENT=development`
- `LOG_LEVEL=DEBUG`
- `ENABLE_DEBUG_ENDPOINTS=true`
- `HOT_RELOAD=true`

## 📱 iOS Development

### iOS Environment Configuration
```swift
// iOS app automatically detects environment
// Development: Uses localhost:8080 (or your Mac IP for device)
// Staging: Uses staging deployment URL  
// Production: Uses production URL

// Debug features enabled in development:
// - Debug logging
// - Testing helpers
// - Environment indicator
// - Dev menu access
```

### iOS Testing on Device
```bash
# Find your Mac's IP address
ifconfig | grep "inet " | grep -v 127.0.0.1

# Update iOS app to use your IP:
# Xcode → Scheme → Environment Variables
# API_BASE_URL = http://YOUR_MAC_IP:8080
```

## 🧪 Testing Strategy

### Test Coverage Goals
- **Unit Tests**: 90%+ coverage
- **Integration Tests**: 80%+ coverage  
- **E2E Tests**: Critical user journeys
- **Performance Tests**: Response time < 2s
- **Security Tests**: No vulnerabilities

### Test Organization
```
backend/tests/
├── unit/           # Fast, isolated tests
├── integration/    # Database, Redis, external APIs
├── e2e/           # Complete user workflows
├── performance/   # Load testing, benchmarks
└── security/      # Security validation
```

## 🔄 CI/CD Pipeline

Your code automatically runs through:

1. **On Push to Feature Branch**:
   - Code quality checks
   - Security scanning
   - Unit tests
   - Integration tests

2. **On PR to Develop**:
   - All above tests
   - Performance tests (if labeled)
   - Build validation

3. **On Merge to Develop**:
   - Deploy to staging environment
   - Run E2E tests against staging
   - Generate deployment artifacts

4. **On Merge to Main**:
   - Deploy to production
   - Run smoke tests
   - Send notifications

## 🎯 Development Best Practices

### Code Standards
- **Python**: Black formatting, type hints, docstrings
- **Commits**: Conventional commits (feat:, fix:, docs:, etc.)
- **Testing**: Write tests for all new features
- **Security**: No secrets in code, regular dependency updates

### Performance Guidelines
- **API Response Time**: < 2 seconds
- **Memory Usage**: < 512MB per container
- **Database Queries**: Use indexes, avoid N+1 queries
- **Caching**: Cache expensive operations

### Security Guidelines
- **API Keys**: Store in secrets/, never in code
- **Input Validation**: Validate all user inputs
- **Rate Limiting**: Protect against abuse
- **Logging**: Log security events, not sensitive data

## 🚨 Troubleshooting

### Common Issues

**Docker Services Won't Start**
```bash
# Check Docker is running
docker info

# Reset Docker environment
docker-compose -f docker-compose.dev.yml down
docker system prune -f
docker-compose -f docker-compose.dev.yml up -d
```

**Python Dependencies Issues**
```bash
cd backend
rm -rf .venv
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements_voice.txt -r requirements-dev.txt
```

**Tests Failing**
```bash
# Ensure test services are running
docker-compose -f docker-compose.dev.yml up -d redis postgres

# Check environment variables
export ENVIRONMENT=testing
export DATABASE_URL="postgresql://dev_user:dev_password@localhost:5432/mervyn_talks_test"
export REDIS_URL="redis://localhost:6379"

# Run tests with verbose output
pytest -v --tb=short
```

**API Key Issues**
```bash
# Verify your secrets file
cat secrets/.env.secrets

# Check API key is loaded
cd backend && source .venv/bin/activate
python -c "import os; print('API Key:', os.environ.get('GEMINI_API_KEY', 'NOT FOUND'))"
```

## 🎉 You're Ready to Build!

Your development environment includes:

✅ **Professional Development Stack** - Docker, hot reload, debugging  
✅ **Comprehensive Testing** - Unit, integration, E2E, performance  
✅ **Code Quality Enforcement** - Linting, formatting, security scanning  
✅ **CI/CD Pipeline** - Automated testing and deployment  
✅ **Monitoring & Observability** - Prometheus, Grafana, Jaeger  
✅ **Documentation** - API docs, guides, examples  

### Next Steps:
1. **Run Setup**: `./scripts/dev-setup.sh`
2. **Add Your API Keys**: Edit `secrets/.env.secrets`
3. **Start Coding**: `./scripts/dev-start.sh`
4. **Create Features**: Follow the workflow above
5. **Ship Fast**: Professional tools for rapid development

**Happy coding! 🚀 Build amazing features for Mervyn Talks!**
