# DisplayDeck Development Guide

This guide helps developers set up and contribute to the DisplayDeck project.

## Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd DisplayDeck

# Initial setup
make setup

# Start development environment
make dev
```

## Development Environment

### Prerequisites
- Docker & Docker Compose
- Python 3.11+ (for backend development)
- Node.js 18+ (for frontend/mobile development)
- Android Studio (for Android TV development)

### Architecture
```
├── backend/           # Django REST API
├── frontend/          # React web app
├── mobile/            # React Native mobile app
├── android-display/   # Android TV display client
├── deployment/        # Docker & deployment configs
└── .github/           # CI/CD workflows
```

## Development Commands

### Setup & Environment
```bash
make setup          # Initial setup with pre-commit hooks
make dev           # Start development containers
make clean         # Clean up containers and volumes
```

### Code Quality
```bash
make lint          # Run all linting
make format        # Format all code
make check-format  # Check code formatting without changes
make test          # Run all tests
```

### Database Operations
```bash
make db-reset      # Reset development database
make db-shell      # Open PostgreSQL shell
```

### Monitoring
```bash
make logs          # View all service logs
make logs-backend  # View backend logs only
make logs-frontend # View frontend logs only
```

## Platform-Specific Development

### Backend (Django)
```bash
cd backend
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements/development.txt
cd src
python manage.py runserver
```

**Key files:**
- `src/core/settings/` - Django settings
- `src/apps/` - Django applications
- `requirements/` - Python dependencies

**Testing:**
```bash
cd backend/src
pytest
pytest --cov=. --cov-report=html  # With coverage
```

### Frontend (React)
```bash
cd frontend
npm install
npm start
```

**Key files:**
- `src/components/ui/` - Reusable UI components
- `src/lib/` - Utilities and helpers
- `tailwind.config.js` - Styling configuration

**Testing:**
```bash
npm test
npm run build  # Production build
```

### Mobile (React Native)
```bash
cd mobile
npm install
npx expo start
```

**Development:**
- Use Expo Go app for testing
- QR scanner functionality for display pairing
- Cross-platform iOS/Android support

### Android TV (Kotlin)
1. Open `android-display/` in Android Studio
2. Sync project with Gradle files
3. Use Android TV emulator or physical device

**Key features:**
- Jetpack Compose UI
- QR code generation for pairing
- WebSocket connection for real-time updates

## Code Style & Standards

### Python (Backend)
- **Formatter:** Black (line length: 88)
- **Import sorting:** isort
- **Linting:** Flake8
- **Type checking:** MyPy

```bash
cd backend
black src/
isort src/
flake8 src/
mypy src/
```

### JavaScript/TypeScript
- **Formatter:** Prettier
- **Linting:** ESLint
- **Style:** Standard with TypeScript support

```bash
# Frontend
cd frontend
npm run format
npm run lint

# Mobile
cd mobile
npm run format
npm run lint
```

## Pre-commit Hooks

Automatically installed with `make setup`. Runs on every commit:

- Code formatting (Black, Prettier)
- Linting (Flake8, ESLint)
- Type checking (MyPy, TypeScript)
- Security scanning (detect-secrets)
- General checks (trailing whitespace, merge conflicts)

## Testing Strategy

### Backend Tests
```bash
cd backend/src
pytest tests/                    # Unit tests
pytest tests/integration/        # Integration tests
pytest tests/api/               # API tests
```

**Test types:**
- Unit tests for models, services, utilities
- Integration tests for database operations
- API tests for endpoints
- WebSocket tests for real-time features

### Frontend Tests
```bash
cd frontend
npm test                        # Jest + React Testing Library
```

**Test types:**
- Component tests
- Hook tests
- Integration tests
- E2E tests (planned)

### Mobile Tests
```bash
cd mobile
npm run test                    # Jest + React Native Testing Library
```

## API Development

### OpenAPI Documentation
- Development: http://localhost:8000/api/schema/swagger-ui/
- Auto-generated from DRF serializers and viewsets

### WebSocket Development
- Development: ws://localhost:8001/ws/
- Channels-based real-time communication
- Authentication required for connections

### Authentication
- JWT-based authentication
- Refresh token rotation
- Permission-based access control

## Database Development

### Migrations
```bash
cd backend/src
python manage.py makemigrations
python manage.py migrate
```

### Seed Data
```bash
python manage.py loaddata fixtures/initial_data.json
python manage.py createsuperuser
```

## Deployment

### Development
```bash
make dev  # Uses docker-compose.dev.yml
```

### Production
```bash
./deploy.sh  # Choose production option
```

### Environment Variables
Copy `.env.example` to `.env` and customize:
```bash
cp .env.example .env
# Edit .env with your settings
```

## Troubleshooting

### Common Issues

**Port conflicts:**
```bash
# Check what's using the ports
netstat -tulpn | grep :8000
sudo lsof -i :8000
```

**Database connection errors:**
```bash
make db-reset  # Reset database
docker-compose logs db  # Check database logs
```

**Node modules issues:**
```bash
cd frontend && rm -rf node_modules package-lock.json && npm install
cd mobile && rm -rf node_modules package-lock.json && npm install
```

**Docker space issues:**
```bash
make clean
docker system df  # Check space usage
docker system prune -a  # Clean everything
```

### Performance Tips

**Backend:**
- Use database query optimization
- Implement Redis caching
- Monitor with Django Debug Toolbar

**Frontend:**
- Use React.memo for expensive components
- Implement code splitting
- Monitor bundle size

## Contributing

### Workflow
1. Create feature branch: `git checkout -b feature/your-feature`
2. Make changes following code standards
3. Run tests: `make test`
4. Run linting: `make lint`
5. Commit with conventional commits
6. Push and create pull request

### Commit Messages
Use conventional commits format:
```
feat: add QR code pairing functionality
fix: resolve WebSocket connection issue
docs: update API documentation
test: add integration tests for menu management
```

### Pull Request Process
1. Ensure CI passes
2. Code review required
3. Update documentation if needed
4. Squash and merge to main

## Resources

- [Django Documentation](https://docs.djangoproject.com/)
- [React Documentation](https://react.dev/)
- [React Native Documentation](https://reactnative.dev/)
- [Expo Documentation](https://docs.expo.dev/)
- [Android Jetpack Compose](https://developer.android.com/jetpack/compose)