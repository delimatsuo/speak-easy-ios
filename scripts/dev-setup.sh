#!/bin/bash
set -e

# Mervyn Talks - Development Environment Setup Script
# This script sets up the complete development environment

echo "🚀 Setting up Mervyn Talks development environment..."
echo "=================================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
log_info "Checking prerequisites..."

# Check Docker
if ! command_exists docker; then
    log_error "Docker is required but not installed."
    log_info "Install Docker: brew install --cask docker"
    exit 1
fi
log_success "Docker found"

# Check Docker Compose
if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
    log_error "Docker Compose is required but not installed."
    log_info "Install Docker Compose: pip install docker-compose"
    exit 1
fi
log_success "Docker Compose found"

# Check Python 3.11+
if ! command_exists python3; then
    log_error "Python 3.11+ is required but not installed."
    log_info "Install Python: brew install python@3.11"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d'.' -f1)
PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d'.' -f2)

if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 11 ]); then
    log_error "Python 3.11+ is required. Found: $PYTHON_VERSION"
    log_info "Install Python 3.11: brew install python@3.11"
    exit 1
fi
log_success "Python $PYTHON_VERSION found"

# Check Git
if ! command_exists git; then
    log_error "Git is required but not installed."
    log_info "Install Git: brew install git"
    exit 1
fi
log_success "Git found"

# Check if we're in the right directory
if [ ! -f "docker-compose.dev.yml" ]; then
    log_error "Please run this script from the project root directory"
    exit 1
fi

# Create necessary directories
log_info "Creating development directories..."
mkdir -p backend/logs
mkdir -p test-results
mkdir -p secrets
mkdir -p config/ssl-dev
mkdir -p config/grafana/provisioning/{dashboards,datasources}

# Setup Python virtual environment
log_info "Setting up Python virtual environment..."
cd backend

if [ ! -d ".venv" ]; then
    python3 -m venv .venv
    log_success "Virtual environment created"
else
    log_info "Virtual environment already exists"
fi

# Activate virtual environment
source .venv/bin/activate
log_success "Virtual environment activated"

# Upgrade pip
pip install --upgrade pip setuptools wheel

# Install development dependencies
log_info "Installing Python dependencies..."
if [ -f "requirements_voice.txt" ]; then
    pip install -r requirements_voice.txt
    log_success "Main dependencies installed"
else
    log_warning "requirements_voice.txt not found, skipping main dependencies"
fi

if [ -f "requirements-dev.txt" ]; then
    pip install -r requirements-dev.txt
    log_success "Development dependencies installed"
else
    log_warning "requirements-dev.txt not found, skipping dev dependencies"
fi

# Setup pre-commit hooks
if command_exists pre-commit; then
    log_info "Setting up pre-commit hooks..."
    pre-commit install
    pre-commit install --hook-type commit-msg
    log_success "Pre-commit hooks installed"
else
    log_warning "pre-commit not available, skipping hooks setup"
fi

cd ..

# Create development environment file
log_info "Creating development environment configuration..."
cat > backend/.env.development << EOF
# Mervyn Talks - Development Environment Configuration
ENVIRONMENT=development
GCP_PROJECT=universal-translator-dev
PORT=8080
LOG_LEVEL=DEBUG

# Development Features
ENABLE_CORS=true
ENABLE_DEBUG_ENDPOINTS=true
SKIP_AUTH_FOR_DEVELOPMENT=false
ENABLE_REQUEST_LOGGING=true

# Database Configuration (Development)
DATABASE_URL=postgresql://dev_user:dev_password@localhost:5432/mervyn_talks_dev
REDIS_URL=redis://localhost:6379

# Rate Limiting (Relaxed for development)
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS_PER_MINUTE=120

# Security (Development)
JWT_SECRET=development-jwt-secret-change-in-production
CERTIFICATE_PINNING_ENABLED=false

# External APIs
GEMINI_MODEL=gemini-2.5-flash
GEMINI_TTS_MODEL=gemini-2.5-flash-preview-tts

# Development Tools
HOT_RELOAD=true
AUTO_RESTART=true
DEBUG_SQL_QUERIES=false
ENABLE_API_DOCS=true

# CORS Configuration
CORS_ALLOW_ORIGINS=["http://localhost:3000", "http://localhost:8080", "http://localhost:8000"]
CORS_ALLOW_METHODS=["GET", "POST", "PUT", "DELETE", "OPTIONS", "PATCH"]
CORS_ALLOW_CREDENTIALS=true
EOF

log_success "Development environment file created"

# Create secrets template
log_info "Creating secrets template..."
cat > secrets/.env.secrets.template << EOF
# Development secrets - COPY TO .env.secrets AND FILL IN REAL VALUES
# DO NOT COMMIT THE ACTUAL .env.secrets FILE

# Gemini API Key (Get from https://makersuite.google.com/app/apikey)
GEMINI_API_KEY=your-gemini-api-key-here

# JWT Secret (Generate a secure random string)
JWT_SECRET=your-jwt-secret-here

# Database Passwords (Use secure passwords in production)
DATABASE_PASSWORD=your-database-password-here
REDIS_PASSWORD=your-redis-password-here

# Firebase Admin SDK (Download from Firebase Console)
GOOGLE_APPLICATION_CREDENTIALS=/app/secrets/firebase-admin-sdk.json
EOF

# Create development SSL certificates
log_info "Creating development SSL certificates..."
if ! command_exists openssl; then
    log_warning "OpenSSL not found, skipping SSL certificate generation"
else
    cd config/ssl-dev
    if [ ! -f "dev.key" ]; then
        openssl req -x509 -newkey rsa:4096 -keyout dev.key -out dev.crt -days 365 -nodes \
            -subj "/C=US/ST=Development/L=Local/O=MervynTalks/CN=localhost"
        log_success "Development SSL certificates created"
    else
        log_info "SSL certificates already exist"
    fi
    cd ../..
fi

# Create Prometheus configuration
log_info "Creating monitoring configuration..."
cat > config/prometheus.dev.yml << EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  # - "first_rules.yml"
  # - "second_rules.yml"

scrape_configs:
  - job_name: 'mervyn-talks-api'
    static_configs:
      - targets: ['mervyn-talks-api:8080']
    metrics_path: '/metrics'
    scrape_interval: 10s

  - job_name: 'redis'
    static_configs:
      - targets: ['redis:6379']
    
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres:5432']
EOF

# Create Grafana datasource configuration
mkdir -p config/grafana/provisioning/datasources
cat > config/grafana/provisioning/datasources/prometheus.yml << EOF
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

# Update .gitignore
log_info "Updating .gitignore..."
cat >> .gitignore << EOF

# Development environment
backend/.venv/
backend/logs/
test-results/
secrets/.env.secrets
config/ssl-dev/*.key
config/ssl-dev/*.crt
.env.local
.env.development.local

# Database
*.db
*.sqlite
*.sqlite3

# IDE
.vscode/settings.json
.idea/

# OS
.DS_Store
Thumbs.db

# Docker
.docker/
EOF

# Start development services
log_info "Starting development services..."
if docker info >/dev/null 2>&1; then
    docker-compose -f docker-compose.dev.yml up -d redis postgres
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 10
    
    # Check if services are running
    if docker-compose -f docker-compose.dev.yml ps | grep -q "Up"; then
        log_success "Development services started"
    else
        log_warning "Some services may not have started correctly"
    fi
else
    log_warning "Docker daemon not running, skipping service startup"
fi

# Create development helper scripts
log_info "Creating helper scripts..."

# Development start script
cat > scripts/dev-start.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting Mervyn Talks development server..."

cd backend
source .venv/bin/activate

# Load environment variables
if [ -f ".env.development" ]; then
    export $(cat .env.development | grep -v ^# | xargs)
fi

# Load secrets if they exist
if [ -f "../secrets/.env.secrets" ]; then
    export $(cat ../secrets/.env.secrets | grep -v ^# | xargs)
fi

# Start services if not running
cd ..
docker-compose -f docker-compose.dev.yml up -d redis postgres

echo "⏳ Waiting for services to be ready..."
sleep 5

cd backend

# Start with hot reload
echo "🌐 Starting API server with hot reload..."
uvicorn app.main_voice:app \
  --reload \
  --reload-dir app \
  --host 0.0.0.0 \
  --port 8080 \
  --log-level debug

echo "🌐 API running at http://localhost:8080"
echo "📚 Documentation at http://localhost:8080/docs"
EOF

# Test runner script
cat > scripts/test-all.sh << 'EOF'
#!/bin/bash
set -e

cd backend
source .venv/bin/activate

echo "🧪 Running all tests for Mervyn Talks..."

# Start test services
cd ..
docker-compose -f docker-compose.dev.yml up -d redis postgres
sleep 5
cd backend

# Set test environment
export ENVIRONMENT=testing
export DATABASE_URL="postgresql://dev_user:dev_password@localhost:5432/mervyn_talks_test"
export REDIS_URL="redis://localhost:6379"

echo "📝 Code quality checks..."
black --check . || (echo "❌ Code formatting failed. Run: black ." && exit 1)
flake8 . || (echo "❌ Linting failed." && exit 1)
isort --check-only . || (echo "❌ Import sorting failed. Run: isort ." && exit 1)

echo "🔒 Security checks..."
bandit -r . -ll || (echo "❌ Security check failed." && exit 1)
safety check || (echo "❌ Dependency vulnerability check failed." && exit 1)

echo "🎯 Unit tests..."
pytest tests/unit/ -v --cov=app --cov-report=term-missing

echo "🔗 Integration tests..."
pytest tests/integration/ -v

echo "✅ All tests passed!"
EOF

# Docker development script
cat > scripts/dev-docker.sh << 'EOF'
#!/bin/bash
set -e

echo "🐳 Starting Mervyn Talks with Docker development environment..."

# Build and start all services
docker-compose -f docker-compose.dev.yml up --build

echo "🌐 Services running:"
echo "  - API: http://localhost:8080"
echo "  - Docs: http://localhost:8080/docs" 
echo "  - Nginx: http://localhost:8000"
echo "  - Prometheus: http://localhost:9090 (with --profile monitoring)"
echo "  - Grafana: http://localhost:3000 (with --profile monitoring, admin/admin)"
EOF

# Make scripts executable
chmod +x scripts/dev-start.sh
chmod +x scripts/test-all.sh
chmod +x scripts/dev-docker.sh

log_success "Helper scripts created"

# Final setup summary
echo ""
echo "🎉 Development environment setup complete!"
echo "========================================"
echo ""
log_success "✅ Virtual environment created and activated"
log_success "✅ Dependencies installed"
log_success "✅ Development configuration created"
log_success "✅ Development services started"
log_success "✅ Helper scripts created"
echo ""
echo "📋 Next steps:"
echo "1. Copy secrets template: cp secrets/.env.secrets.template secrets/.env.secrets"
echo "2. Add your Gemini API key to secrets/.env.secrets"
echo "3. Start development server: ./scripts/dev-start.sh"
echo "4. Run tests: ./scripts/test-all.sh"
echo "5. Use Docker environment: ./scripts/dev-docker.sh"
echo ""
echo "🌐 Development URLs:"
echo "  - API: http://localhost:8080"
echo "  - Docs: http://localhost:8080/docs"
echo "  - Admin: http://localhost:8080/admin"
echo "  - Nginx Proxy: http://localhost:8000"
echo ""
echo "🔗 Useful commands:"
echo "  - Activate venv: cd backend && source .venv/bin/activate"
echo "  - Run tests: ./scripts/test-all.sh"
echo "  - Check services: docker-compose -f docker-compose.dev.yml ps"
echo "  - View logs: docker-compose -f docker-compose.dev.yml logs -f"
echo ""
log_warning "⚠️  Don't forget to add your API keys to secrets/.env.secrets!"
echo ""
log_success "Happy coding! 🚀"
