# DisplayDeck Development Makefile

.PHONY: help dev setup clean build test lint format check-format install-hooks

# Default target
help:
	@echo "Available commands:"
	@echo "  setup         - Initial project setup"
	@echo "  dev           - Start development environment"
	@echo "  build         - Build all services"
	@echo "  test          - Run all tests"
	@echo "  lint          - Run all linting"
	@echo "  format        - Format all code"
	@echo "  check-format  - Check code formatting"
	@echo "  clean         - Clean up containers and volumes"
	@echo "  install-hooks - Install pre-commit hooks"

# Initial setup
setup: install-hooks
	@echo "🚀 Setting up DisplayDeck development environment..."
	docker-compose -f docker-compose.dev.yml build
	@echo "✅ Setup complete!"

# Start development environment
dev:
	@echo "🛠️  Starting development environment..."
	docker-compose -f docker-compose.dev.yml up -d
	@echo "✅ Development environment started!"
	@echo "Frontend: http://localhost:3000"
	@echo "Backend: http://localhost:8000"
	@echo "Admin: http://localhost:8000/admin"

# Build production images
build:
	@echo "🏭 Building production images..."
	docker-compose build

# Run all tests
test: test-backend test-frontend test-mobile

test-backend:
	@echo "🧪 Running backend tests..."
	cd backend && python -m pytest

test-frontend:
	@echo "🧪 Running frontend tests..."
	cd frontend && npm test -- --watchAll=false

test-mobile:
	@echo "🧪 Running mobile tests..."
	cd mobile && npm run type-check

# Linting
lint: lint-backend lint-frontend lint-mobile

lint-backend:
	@echo "🔍 Linting backend..."
	cd backend && flake8 src/
	cd backend && black --check src/
	cd backend && isort --check-only src/
	cd backend && mypy src/

lint-frontend:
	@echo "🔍 Linting frontend..."
	cd frontend && npm run lint
	cd frontend && npm run type-check

lint-mobile:
	@echo "🔍 Linting mobile..."
	cd mobile && npm run lint
	cd mobile && npm run type-check

# Formatting
format: format-backend format-frontend format-mobile

format-backend:
	@echo "✨ Formatting backend..."
	cd backend && black src/
	cd backend && isort src/

format-frontend:
	@echo "✨ Formatting frontend..."
	cd frontend && npm run format

format-mobile:
	@echo "✨ Formatting mobile..."
	cd mobile && npm run format

# Check formatting
check-format: check-format-backend check-format-frontend check-format-mobile

check-format-backend:
	@echo "🔍 Checking backend formatting..."
	cd backend && black --check src/
	cd backend && isort --check-only src/

check-format-frontend:
	@echo "🔍 Checking frontend formatting..."
	cd frontend && npm run format:check

check-format-mobile:
	@echo "🔍 Checking mobile formatting..."
	cd mobile && npm run format:check

# Install pre-commit hooks
install-hooks:
	@echo "🪝 Installing pre-commit hooks..."
	pip install pre-commit
	pre-commit install
	@echo "✅ Pre-commit hooks installed!"

# Clean up
clean:
	@echo "🧹 Cleaning up..."
	docker-compose -f docker-compose.dev.yml down -v
	docker-compose down -v
	docker system prune -f
	@echo "✅ Cleanup complete!"

# Database operations
db-reset:
	@echo "🔄 Resetting database..."
	docker-compose -f docker-compose.dev.yml stop backend
	docker-compose -f docker-compose.dev.yml rm -f db
	docker-compose -f docker-compose.dev.yml up -d db
	sleep 5
	docker-compose -f docker-compose.dev.yml run --rm backend python manage.py migrate
	@echo "✅ Database reset complete!"

db-shell:
	@echo "🐘 Opening database shell..."
	docker-compose -f docker-compose.dev.yml exec db psql -U postgres -d displaydeck

# Logs
logs:
	docker-compose -f docker-compose.dev.yml logs -f

logs-backend:
	docker-compose -f docker-compose.dev.yml logs -f backend

logs-frontend:
	docker-compose -f docker-compose.dev.yml logs -f frontend

# Install dependencies
install-deps: install-backend-deps install-frontend-deps install-mobile-deps

install-backend-deps:
	@echo "📦 Installing backend dependencies..."
	cd backend && pip install -r requirements/development.txt

install-frontend-deps:
	@echo "📦 Installing frontend dependencies..."
	cd frontend && npm install

install-mobile-deps:
	@echo "📦 Installing mobile dependencies..."
	cd mobile && npm install