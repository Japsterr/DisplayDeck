-- Create database and user for DisplayDeck
-- This will be executed when the PostgreSQL container starts

-- Create additional databases if needed
-- CREATE DATABASE displaydeck_test;

-- Create extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create initial admin user (optional)
-- This would normally be done through Django management commands