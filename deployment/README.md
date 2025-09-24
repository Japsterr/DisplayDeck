# DisplayDeck Deployment Guide

DisplayDeck is a comprehensive digital menu management system for fast food restaurants with multi-platform support.

## Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   React Web     │    │  React Native   │    │   Android TV    │
│    Frontend     │    │   Mobile App    │    │  Display Client │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │      Nginx      │
                    │  Reverse Proxy  │
                    └─────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Django REST    │    │ Django Channels │    │    Celery       │
│      API        │    │   WebSockets    │    │ Background Jobs │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐
│   PostgreSQL    │    │      Redis      │
│    Database     │    │  Cache & Queue  │
└─────────────────┘    └─────────────────┘
```

## Prerequisites

- Docker 20.10 or later
- Docker Compose 2.0 or later
- At least 4GB RAM available for containers
- 10GB free disk space

## Quick Start

### 1. Clone and Setup
```bash
git clone <your-repo-url>
cd DisplayDeck
cp .env.example .env
```

### 2. Configure Environment
Edit `.env` file with your settings:
```bash
# Essential settings to change:
SECRET_KEY=your-super-secret-key-here
DB_PASSWORD=secure-database-password
ALLOWED_HOSTS=your-domain.com,localhost
```

### 3. Deploy
For development:
```bash
chmod +x deploy.sh
./deploy.sh
# Choose option 1 for development
```

For production:
```bash
./deploy.sh
# Choose option 2 for production
```

## Services Overview

| Service | Port | Purpose |
|---------|------|---------|
| Frontend | 3000 | React web application |
| Backend API | 8000 | Django REST API |
| WebSocket | 8001 | Real-time updates |
| Database | 5432 | PostgreSQL |
| Cache | 6379 | Redis |
| Nginx | 80/443 | Reverse proxy & load balancer |

## Development Setup

### Backend Development
```bash
cd backend
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate     # Windows

pip install -r requirements/development.txt
cd src
python manage.py migrate
python manage.py runserver
```

### Frontend Development
```bash
cd frontend
npm install
npm start
```

### Mobile Development
```bash
cd mobile
npm install
npx expo start
```

### Android TV Development
1. Open `android-display` folder in Android Studio
2. Sync project with Gradle files
3. Run on Android TV emulator or device

## Production Deployment

### Server Requirements
- Ubuntu 20.04 LTS or later
- 4GB RAM minimum, 8GB recommended
- 50GB SSD storage minimum
- SSL certificate (Let's Encrypt recommended)

### Production Setup
1. **Server Setup**
   ```bash
   sudo apt update
   sudo apt install docker.io docker-compose-plugin
   sudo systemctl start docker
   sudo systemctl enable docker
   sudo usermod -aG docker $USER
   ```

2. **SSL Configuration**
   ```bash
   # Install Certbot
   sudo apt install certbot
   sudo certbot certonly --standalone -d your-domain.com
   
   # Copy certificates to deployment/ssl/
   sudo cp /etc/letsencrypt/live/your-domain.com/fullchain.pem deployment/ssl/
   sudo cp /etc/letsencrypt/live/your-domain.com/privkey.pem deployment/ssl/
   ```

3. **Deploy Application**
   ```bash
   ./deploy.sh
   # Choose option 2 for production
   ```

### Production Environment Variables
Key variables to set in `.env`:
```bash
DEBUG=False
SECRET_KEY=your-super-secure-secret-key
ALLOWED_HOSTS=your-domain.com
DB_PASSWORD=secure-database-password
SENTRY_DSN=your-sentry-dsn-for-error-tracking
```

## Monitoring and Maintenance

### Health Checks
```bash
# Check all services
docker-compose ps

# View logs
docker-compose logs -f

# Check specific service
docker-compose logs -f backend
```

### Backup Database
```bash
# Create backup
docker-compose exec db pg_dump -U postgres displaydeck > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore backup
docker-compose exec -T db psql -U postgres displaydeck < backup_file.sql
```

### Scaling Services
```bash
# Scale backend workers
docker-compose up -d --scale backend=3

# Scale celery workers
docker-compose up -d --scale celery=2
```

## Security Considerations

### Production Security Checklist
- [ ] Change default passwords
- [ ] Set strong SECRET_KEY
- [ ] Configure SSL/TLS
- [ ] Enable firewall (UFW)
- [ ] Set up automated backups
- [ ] Configure log rotation
- [ ] Enable fail2ban for SSH protection
- [ ] Regular security updates

### Network Security
```bash
# Configure UFW firewall
sudo ufw allow 22      # SSH
sudo ufw allow 80      # HTTP
sudo ufw allow 443     # HTTPS
sudo ufw enable
```

## Mobile App Deployment

### React Native (iOS/Android)
```bash
cd mobile
npm install

# For iOS
npx expo build:ios

# For Android
npx expo build:android
```

### Android TV App
1. Open project in Android Studio
2. Generate signed APK: Build → Generate Signed Bundle/APK
3. Distribute APK to Android TV devices

## API Documentation

Once deployed, access API documentation at:
- Development: http://localhost:8000/api/schema/swagger-ui/
- Production: https://your-domain.com/api/schema/swagger-ui/

## Troubleshooting

### Common Issues

**Services won't start:**
```bash
# Check Docker daemon
sudo systemctl status docker

# Check logs
docker-compose logs
```

**Database connection errors:**
```bash
# Reset database
docker-compose down -v
docker-compose up -d db
docker-compose exec backend python manage.py migrate
```

**Frontend build errors:**
```bash
cd frontend
rm -rf node_modules package-lock.json
npm install
npm run build
```

### Performance Optimization

**Database Performance:**
```sql
-- Enable query logging
ALTER SYSTEM SET log_statement = 'all';
SELECT pg_reload_conf();
```

**Redis Performance:**
```bash
# Monitor Redis
docker-compose exec redis redis-cli monitor
```

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review service logs
3. Create an issue in the repository

## License

This project is licensed under the MIT License.