# 📍 Mervyn Talks - Project Navigation Index

## 🎯 **Quick Reference for AI Agents**

**Use this as your navigation hub to quickly find what you need.**

---

## 📚 **Essential Documents (READ FIRST)**

| Priority | Document | Purpose | When to Read |
|----------|----------|---------|--------------|
| **🔥 1** | `AI_AGENT_ONBOARDING.md` | **REQUIRED**: Complete project overview | **ALWAYS READ FIRST** |
| **🔥 2** | `DEVELOPMENT_QUICK_START.md` | Immediate development workflow | Starting development |
| **🔥 3** | `DEV_ENVIRONMENT_SETUP.md` | Complete development setup | Setting up environment |
| **📊 4** | `MARKETING_STRATEGY.md` | Business context & user needs | Understanding product |
| **🎯 5** | `ADMIN_DASHBOARD_GUIDE.md` | Admin features & analytics | Backend/admin work |

---

## 🏗️ **Architecture Quick Reference**

### **Technology Stack**
```
📱 Frontend: iOS (Swift/SwiftUI)
🔗 Backend: Python (FastAPI) 
🧠 AI: Google Gemini 2.5 Flash + TTS
☁️ Cloud: Google Cloud Platform
🗄️ Database: PostgreSQL + Redis
🐳 Development: Docker + GitHub Actions
```

### **Key Services**
```
Translation API     → backend/app/services/translation.py
Text-to-Speech     → backend/app/services/tts.py  
Rate Limiting      → backend/app/managers/rate_limiter.py
User Management    → backend/app/models/user.py
iOS App Entry      → iOS/Sources/App/UniversalTranslatorApp.swift
Environment Config → iOS/Sources/Configuration/EnvironmentConfig.swift
```

---

## 📁 **File Location Quick Finder**

### **🔗 Backend Development**
| What you need | File Location |
|---------------|---------------|
| **Main API** | `backend/app/main_voice.py` |
| **Translation Service** | `backend/app/services/translation.py` |
| **Database Models** | `backend/app/models/` |
| **API Tests** | `backend/tests/unit/test_*.py` |
| **Integration Tests** | `backend/tests/integration/` |
| **Configuration** | `backend/.env.development` |
| **Dependencies** | `backend/requirements_voice.txt` |

### **📱 iOS Development**
| What you need | File Location |
|---------------|---------------|
| **App Entry Point** | `iOS/Sources/App/UniversalTranslatorApp.swift` |
| **Main UI** | `iOS/Sources/Views/ContentView.swift` |
| **Translation Service** | `iOS/Sources/Services/TranslationService.swift` |
| **Environment Config** | `iOS/Sources/Configuration/EnvironmentConfig.swift` |
| **Credit Management** | `iOS/Sources/Managers/CreditsManager.swift` |
| **UI Components** | `iOS/Sources/Components/` |
| **Legal Documents** | `iOS/Resources/Legal/` |

### **🐳 Development Environment**
| What you need | File Location |
|---------------|---------------|
| **Docker Compose** | `docker-compose.dev.yml` |
| **Setup Script** | `scripts/dev-setup.sh` |
| **Development Scripts** | `scripts/dev-start.sh`, `scripts/test-all.sh` |
| **nginx Config** | `config/nginx.dev.conf` |
| **Database Init** | `config/postgres-init.sql` |
| **Pre-commit Hooks** | `.pre-commit-config.yaml` |

### **🔄 CI/CD & Deployment**
| What you need | File Location |
|---------------|---------------|
| **GitHub Actions** | `.github/workflows/development.yml` |
| **Production Docker** | `backend/Dockerfile` |
| **Development Docker** | `backend/Dockerfile.dev` |
| **Cloud Build** | `cloudbuild.yaml` |
| **Firebase Config** | `firebase.json` |

### **📊 Admin & Analytics**
| What you need | File Location |
|---------------|---------------|
| **Admin Dashboard** | `admin/enhanced-admin.html` |
| **Admin Scripts** | `scripts/grant_admin.py` |
| **Analytics Endpoints** | `backend/app/main_voice.py` (admin routes) |
| **Deployment Script** | `deploy-admin.sh` |

### **🎯 Marketing & Business**
| What you need | File Location |
|---------------|---------------|
| **Marketing Strategy** | `MARKETING_STRATEGY.md` |
| **Video Generation** | `marketing/AI_VIDEO_GENERATION_GUIDE.md` |
| **Content Templates** | `marketing/CONTENT_TEMPLATES.md` |
| **Launch Checklist** | `marketing/LAUNCH_CHECKLIST.md` |
| **Social Media** | `marketing/SOCIAL_MEDIA_SETUP.md` |

---

## 🚀 **Quick Commands Reference**

### **Development Setup**
```bash
./scripts/dev-setup.sh          # One-time environment setup
cp secrets/.env.secrets.template secrets/.env.secrets  # Add API keys
./scripts/dev-start.sh           # Start development server
```

### **Testing**
```bash
./scripts/test-all.sh            # Run all tests
cd backend && source .venv/bin/activate
pytest tests/unit/ -v            # Unit tests only
pytest tests/integration/ -v     # Integration tests only
pytest --cov=app                 # With coverage
```

### **Git Workflow**
```bash
git checkout develop             # Switch to develop branch
git checkout -b feature/name     # Create feature branch
git add . && git commit -m "feat: description"  # Commit changes
git push -u origin feature/name  # Push and create PR
```

### **Docker Services**
```bash
docker-compose -f docker-compose.dev.yml up -d    # Start services
docker-compose -f docker-compose.dev.yml down     # Stop services
docker-compose -f docker-compose.dev.yml logs -f  # View logs
```

---

## 🌐 **Development URLs**

| Service | URL | Purpose |
|---------|-----|---------|
| **Backend API** | http://localhost:8080 | Main API endpoints |
| **API Documentation** | http://localhost:8080/docs | Swagger UI |
| **Admin Dashboard** | http://localhost:8080/admin | User management |
| **nginx Proxy** | http://localhost:8000 | Load balanced proxy |
| **Prometheus** | http://localhost:9090 | Metrics (monitoring profile) |
| **Grafana** | http://localhost:3000 | Dashboards (admin/admin) |
| **Jaeger** | http://localhost:16686 | Distributed tracing |

---

## 🔍 **Common Development Scenarios**

### **🆕 Adding a New API Endpoint**
1. **Read**: `backend/app/main_voice.py` (existing patterns)
2. **Edit**: Add new route to `backend/app/main_voice.py`
3. **Test**: Create tests in `backend/tests/unit/`
4. **Document**: FastAPI auto-generates docs

### **🆕 Adding iOS Features**
1. **Read**: `iOS/Sources/Views/ContentView.swift` (main UI)
2. **Create**: New view in `iOS/Sources/Views/`
3. **Integrate**: Update navigation and services
4. **Test**: Manual testing and iOS unit tests

### **🔧 Modifying Translation Logic**
1. **Read**: `backend/app/services/translation.py`
2. **Understand**: Current Gemini API integration
3. **Test**: `backend/tests/unit/test_translation_service.py`
4. **Modify**: Service implementation
5. **Validate**: Run comprehensive tests

### **🎨 UI/UX Changes**
1. **Read**: `iOS/Sources/Components/` (existing components)
2. **Review**: `iOS/Sources/Utilities/SpeakEasyColors.swift` (design system)
3. **Modify**: Relevant SwiftUI views
4. **Test**: Device testing and accessibility

### **🔐 Security Enhancements**
1. **Read**: `SECURITY_IMPLEMENTATION_REPORT.md`
2. **Review**: `backend/app/security/` services
3. **Test**: `backend/tests/security/`
4. **Validate**: Run security scans

### **📊 Analytics & Monitoring**
1. **Read**: `ADMIN_DASHBOARD_GUIDE.md`
2. **Review**: `admin/enhanced-admin.html`
3. **Backend**: Analytics endpoints in `backend/app/main_voice.py`
4. **Test**: Admin dashboard functionality

---

## 🧭 **Navigation by Role**

### **Backend Developer**
**Start Here**: `AI_AGENT_ONBOARDING.md` → `backend/app/main_voice.py` → `backend/tests/`
**Key Dirs**: `backend/app/`, `backend/tests/`, `config/`

### **iOS Developer**  
**Start Here**: `AI_AGENT_ONBOARDING.md` → `iOS/Sources/App/` → `iOS/Sources/Views/`
**Key Dirs**: `iOS/Sources/`, `iOS/Resources/`, `iOS/Documentation/`

### **DevOps/Infrastructure**
**Start Here**: `DEV_ENVIRONMENT_SETUP.md` → `docker-compose.dev.yml` → `.github/workflows/`
**Key Files**: CI/CD configs, Docker files, deployment scripts

### **Product/Marketing**
**Start Here**: `MARKETING_STRATEGY.md` → `marketing/` → `admin/`
**Key Dirs**: `marketing/`, `admin/`, business documentation

### **QA/Testing**
**Start Here**: `backend/tests/conftest.py` → test directories → CI/CD pipeline
**Key Dirs**: `backend/tests/`, `Tests/`, `.github/workflows/`

---

## ⚡ **Emergency Troubleshooting**

### **🚨 Development Environment Broken**
```bash
# Nuclear reset
docker-compose -f docker-compose.dev.yml down
docker system prune -f
rm -rf backend/.venv
./scripts/dev-setup.sh
```

### **🚨 Tests Failing**
```bash
# Check environment
export ENVIRONMENT=testing
export DATABASE_URL="postgresql://dev_user:dev_password@localhost:5432/mervyn_talks_test"
export REDIS_URL="redis://localhost:6379"

# Restart test services
docker-compose -f docker-compose.dev.yml up -d redis postgres
sleep 5

# Run with verbose output
cd backend && source .venv/bin/activate
pytest -v --tb=short
```

### **🚨 API Not Working**
```bash
# Check if services are running
docker-compose -f docker-compose.dev.yml ps

# Check API health
curl http://localhost:8080/health

# Check logs
docker-compose -f docker-compose.dev.yml logs -f mervyn-talks-api
```

### **🚨 iOS Build Issues**
1. Check `iOS/Sources/Configuration/EnvironmentConfig.swift`
2. Verify API_BASE_URL in Xcode scheme
3. Clean build folder (Cmd+Shift+K)
4. Reset simulator if needed

---

## 📞 **Getting Help**

### **Understanding the Codebase**
1. **Start with**: `AI_AGENT_ONBOARDING.md` (this gives you the big picture)
2. **Architecture questions**: Review architecture diagrams and service descriptions
3. **API questions**: Check `http://localhost:8080/docs` (interactive docs)
4. **iOS questions**: Look at `iOS/Sources/Configuration/EnvironmentConfig.swift`

### **Development Issues**
1. **Environment setup**: Follow `DEVELOPMENT_QUICK_START.md` step by step
2. **Testing issues**: Check `backend/tests/conftest.py` for test configuration
3. **Docker issues**: Review `docker-compose.dev.yml` and restart services

### **Business Logic Questions**
1. **User flow**: Review `MARKETING_STRATEGY.md` for user journeys
2. **Features**: Check `ADMIN_DASHBOARD_GUIDE.md` for admin features
3. **Credit system**: See `iOS/Sources/Managers/CreditsManager.swift`

---

## 🎯 **Success Checklist for New AI Agents**

### **Before You Start Coding**
- [ ] Read `AI_AGENT_ONBOARDING.md` completely
- [ ] Understand the technology stack and architecture
- [ ] Set up development environment successfully
- [ ] Run existing tests and confirm they pass
- [ ] Explore the codebase structure

### **Ready to Contribute**
- [ ] Can start development server (`./scripts/dev-start.sh`)
- [ ] Can run tests successfully (`./scripts/test-all.sh`)
- [ ] Understand Git workflow (GitFlow branching)
- [ ] Know where to find relevant code for your task
- [ ] Understand testing and quality requirements

### **Coding Best Practices**
- [ ] Follow existing code patterns and conventions
- [ ] Write tests for new functionality
- [ ] Run quality checks before committing
- [ ] Update documentation when needed
- [ ] Use proper commit messages

---

**🎉 You're ready to contribute to Mervyn Talks!**

This navigation guide helps you quickly find what you need. The project has professional development infrastructure, comprehensive testing, and clear documentation. 

**Happy coding! 🚀**
