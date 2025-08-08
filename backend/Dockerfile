# Production Dockerfile for Cloud Run
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching (use voice stack)
COPY requirements_voice.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements_voice.txt || pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create non-root user for security
RUN useradd -m -u 1000 appuser && chown -R appuser:appuser /app
USER appuser

# Environment variables (secrets loaded at runtime from Secret Manager)
ENV PORT=8080
ENV PYTHONUNBUFFERED=1
# Don't set GOOGLE_APPLICATION_CREDENTIALS - Cloud Run provides it automatically

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8080/health')"

# Expose port
EXPOSE 8080

# Start the voice API application (provides /v1/translate/audio)
CMD ["uvicorn", "app.main_voice:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "4"]