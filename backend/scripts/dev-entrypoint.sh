#!/bin/bash
set -e

echo "🚀 Starting Mervyn Talks Development Server..."

# Wait for dependencies to be ready
echo "⏳ Waiting for dependencies..."

# Wait for Redis
if [ ! -z "$REDIS_URL" ]; then
    echo "Waiting for Redis..."
    until redis-cli -u "$REDIS_URL" ping >/dev/null 2>&1; do
        echo "Redis is unavailable - sleeping"
        sleep 2
    done
    echo "✅ Redis is ready"
fi

# Wait for PostgreSQL
if [ ! -z "$DATABASE_URL" ]; then
    echo "Waiting for PostgreSQL..."
    until pg_isready -d "$DATABASE_URL" >/dev/null 2>&1; do
        echo "PostgreSQL is unavailable - sleeping"
        sleep 2
    done
    echo "✅ PostgreSQL is ready"
fi

# Load environment variables from .env files
if [ -f ".env.development" ]; then
    echo "📝 Loading development environment variables..."
    export $(cat .env.development | grep -v ^# | xargs)
fi

# Run database migrations if needed
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "🔄 Running database migrations..."
    python -c "
import asyncio
from app.database import create_tables
asyncio.run(create_tables())
"
fi

# Initialize development data if needed
if [ "$LOAD_DEV_DATA" = "true" ]; then
    echo "📊 Loading development data..."
    python scripts/load_dev_data.py
fi

echo "🌟 Development environment ready!"
echo "📡 API will be available at: http://localhost:8080"
echo "📚 API Documentation: http://localhost:8080/docs"
echo "🔧 Admin Dashboard: http://localhost:8080/admin"

# Execute the main command
exec "$@"
