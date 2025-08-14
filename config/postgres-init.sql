-- PostgreSQL initialization script for Mervyn Talks development environment
-- This script sets up the development database with proper permissions and extensions

-- Create development database if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mervyn_talks_dev') THEN
        CREATE DATABASE mervyn_talks_dev;
    END IF;
END
$$;

-- Create test database for automated testing
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'mervyn_talks_test') THEN
        CREATE DATABASE mervyn_talks_test;
    END IF;
END
$$;

-- Connect to the development database
\c mervyn_talks_dev;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- For text search
CREATE EXTENSION IF NOT EXISTS "btree_gin"; -- For performance

-- Create development-specific schemas
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS audit;

-- Grant permissions to development user
GRANT ALL PRIVILEGES ON SCHEMA app TO dev_user;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO dev_user;
GRANT ALL PRIVILEGES ON SCHEMA audit TO dev_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO dev_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app TO dev_user;
GRANT ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA app TO dev_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON TABLES TO dev_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON SEQUENCES TO dev_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA app GRANT ALL ON FUNCTIONS TO dev_user;

-- Development-specific configurations
ALTER SYSTEM SET log_statement = 'all';  -- Log all statements for development
ALTER SYSTEM SET log_min_duration_statement = 0;  -- Log all query durations
ALTER SYSTEM SET log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h ';

-- Create basic tables structure (will be managed by application migrations)
CREATE TABLE IF NOT EXISTS app.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE TABLE IF NOT EXISTS app.user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES app.users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    user_agent TEXT,
    ip_address INET
);

CREATE TABLE IF NOT EXISTS app.credits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES app.users(id) ON DELETE CASCADE,
    seconds_remaining INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

CREATE TABLE IF NOT EXISTS app.translation_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES app.users(id) ON DELETE CASCADE,
    source_language VARCHAR(10) NOT NULL,
    target_language VARCHAR(10) NOT NULL,
    source_text TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    confidence_score DECIMAL(3,2),
    processing_time_ms INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_id UUID
);

-- Analytics tables
CREATE TABLE IF NOT EXISTS analytics.api_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INTEGER NOT NULL,
    response_time_ms INTEGER NOT NULL,
    user_id UUID,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS analytics.feature_usage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    feature_name VARCHAR(100) NOT NULL,
    user_id UUID,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Audit tables
CREATE TABLE IF NOT EXISTS audit.data_changes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    table_name VARCHAR(100) NOT NULL,
    operation VARCHAR(10) NOT NULL,  -- INSERT, UPDATE, DELETE
    old_values JSONB,
    new_values JSONB,
    user_id UUID,
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_email ON app.users(email);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON app.users(created_at);
CREATE INDEX IF NOT EXISTS idx_user_sessions_token ON app.user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON app.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_credits_user_id ON app.credits(user_id);
CREATE INDEX IF NOT EXISTS idx_translation_history_user_id ON app.translation_history(user_id);
CREATE INDEX IF NOT EXISTS idx_translation_history_created_at ON app.translation_history(created_at);
CREATE INDEX IF NOT EXISTS idx_api_requests_created_at ON analytics.api_requests(created_at);
CREATE INDEX IF NOT EXISTS idx_api_requests_endpoint ON analytics.api_requests(endpoint);

-- Create development data insertion function
CREATE OR REPLACE FUNCTION app.insert_dev_data()
RETURNS VOID AS $$
BEGIN
    -- Insert development admin user
    INSERT INTO app.users (id, email, created_at, metadata) 
    VALUES (
        'a0000000-0000-0000-0000-000000000001'::uuid,
        'admin@mervyn-talks.dev',
        NOW(),
        '{"role": "admin", "is_dev_user": true}'::jsonb
    ) ON CONFLICT (email) DO NOTHING;
    
    -- Insert development test users
    INSERT INTO app.users (email, created_at, metadata)
    SELECT 
        'user' || i || '@mervyn-talks.dev',
        NOW() - (i || ' days')::interval,
        ('{"role": "user", "is_dev_user": true, "test_user_id": ' || i || '}')::jsonb
    FROM generate_series(1, 5) i
    ON CONFLICT (email) DO NOTHING;
    
    -- Insert credits for development users
    INSERT INTO app.credits (user_id, seconds_remaining, created_at)
    SELECT 
        u.id,
        CASE 
            WHEN u.email LIKE 'admin%' THEN 3600  -- 1 hour for admin
            ELSE 600  -- 10 minutes for test users
        END,
        NOW()
    FROM app.users u
    WHERE u.email LIKE '%@mervyn-talks.dev'
    ON CONFLICT (user_id) DO UPDATE SET 
        seconds_remaining = EXCLUDED.seconds_remaining,
        updated_at = NOW();
        
    RAISE NOTICE 'Development data inserted successfully';
END;
$$ LANGUAGE plpgsql;

-- Create function to reset development data
CREATE OR REPLACE FUNCTION app.reset_dev_data()
RETURNS VOID AS $$
BEGIN
    -- Clear all data except schema
    TRUNCATE app.translation_history, app.credits, app.user_sessions, app.users CASCADE;
    TRUNCATE analytics.api_requests, analytics.feature_usage CASCADE;
    TRUNCATE audit.data_changes CASCADE;
    
    -- Re-insert development data
    PERFORM app.insert_dev_data();
    
    RAISE NOTICE 'Development data reset successfully';
END;
$$ LANGUAGE plpgsql;

-- Insert initial development data
SELECT app.insert_dev_data();

-- Set up the test database with the same structure
\c mervyn_talks_test;

-- Enable extensions for test database
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";

-- Create schemas for test database
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS analytics;
CREATE SCHEMA IF NOT EXISTS audit;

-- Grant permissions for test database
GRANT ALL PRIVILEGES ON SCHEMA app TO dev_user;
GRANT ALL PRIVILEGES ON SCHEMA analytics TO dev_user;
GRANT ALL PRIVILEGES ON SCHEMA audit TO dev_user;

-- Create the same table structure for testing
-- (Copy the same tables from above)
-- Note: In a real setup, you'd use database migrations to manage this

RAISE NOTICE 'PostgreSQL development environment initialized successfully';
RAISE NOTICE 'Databases created: mervyn_talks_dev, mervyn_talks_test';
RAISE NOTICE 'Development data loaded for testing';
