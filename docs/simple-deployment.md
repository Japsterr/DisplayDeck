# DisplayDeck Simple Deployment (No Traefik)

Simple deployment guide for DisplayDeck without Traefik - using only Nginx or direct access.

## Quick Start Options

### Option 1: Standard Deployment with Nginx (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/Japsterr/DisplayDeck.git
cd DisplayDeck

# 2. Set environment variables
cp .env.example .env
# Edit .env with your database passwords and domain

# 3. Deploy with standard Nginx setup
docker-compose -f deployment/docker/docker-compose.prod.yml up -d

# 4. Access the application
# Frontend: http://your-domain.com
# Backend API: http://your-domain.com/api/v1
# Admin: http://your-domain.com/admin
```

### Option 2: Simple Direct Access (No Reverse Proxy)

```bash
# 1. Deploy core services only
docker-compose up -d postgres redis backend frontend

# 2. Access directly
# Frontend: http://localhost:3000
# Backend API: http://localhost:8000/api/v1
# Admin: http://localhost:8000/admin
```

### Option 3: Development Mode

```bash
# 1. Use development docker-compose
docker-compose -f docker-compose.dev.yml up -d

# 2. Access development environment
# Frontend: http://localhost:3000
# Backend API: http://localhost:8001/api/v1
```

## Environment Configuration

Create `.env` file with these required variables:

```bash
# Database
POSTGRES_PASSWORD=your_secure_password
POSTGRES_USER=displaydeck
POSTGRES_DB=displaydeck

# Django
SECRET_KEY=your-very-long-secret-key-here
DEBUG=False
ALLOWED_HOSTS=localhost,127.0.0.1,your-domain.com

# URLs (for simple deployment)
VITE_API_BASE_URL=http://localhost:8000
VITE_WS_URL=ws://localhost:8000

# Optional: SSL Email (only if using Let's Encrypt)
LETSENCRYPT_EMAIL=admin@your-domain.com
DOMAIN_NAME=your-domain.com
```

## Architecture

### Standard Nginx Setup
```
Internet → Nginx (Port 80/443) → Backend (Port 8000) + Frontend (Port 3000)
                                ↓
                          PostgreSQL + Redis
```

### Simple Direct Access
```
Internet → Backend (Port 8000) + Frontend (Port 3000)
                  ↓
            PostgreSQL + Redis
```

## SSL Certificate Options

### Option 1: Let's Encrypt with Nginx (Automatic)
The nginx setup includes automatic Let's Encrypt certificates:

```bash
# SSL certificates are handled automatically
# Just set your domain in .env file
DOMAIN_NAME=your-domain.com
LETSENCRYPT_EMAIL=admin@your-domain.com
```

### Option 2: Manual SSL Certificates
If you have your own SSL certificates:

```bash
# Place certificates in deployment/ssl/
cp your-domain.crt deployment/ssl/
cp your-domain.key deployment/ssl/
```

### Option 3: HTTP Only (Development/Internal)
For development or internal use without SSL:

```bash
# Just use HTTP ports
# Frontend: http://localhost:3000
# Backend: http://localhost:8000
```

## Database Setup

The system will automatically create the database and run migrations:

```bash
# Database is created automatically when containers start
# Migrations run automatically via Django
# Default admin user is created with:
# Username: admin
# Password: admin (change immediately after first login)
```

## Monitoring (Optional)

If you want monitoring without complexity:

```bash
# Simple health checks are built into all services
# Check service health:
docker-compose ps

# View logs:
docker-compose logs backend
docker-compose logs frontend
```

## Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # If ports are in use, modify docker-compose.yml
   # Change ports like: "3001:3000" instead of "3000:3000"
   ```

2. **Permission Issues**
   ```bash
   # Fix Docker permissions
   sudo chown -R $USER:$USER .
   ```

3. **Database Connection Issues**
   ```bash
   # Check PostgreSQL is running
   docker-compose logs postgres
   
   # Reset database if needed
   docker-compose down -v
   docker-compose up -d
   ```

## Production Checklist

- [ ] Change default admin password
- [ ] Set strong SECRET_KEY in .env
- [ ] Set strong database passwords
- [ ] Configure your domain name
- [ ] Set up SSL certificates (recommended)
- [ ] Configure backup strategy
- [ ] Set up monitoring (optional)

## Security Notes

- All services run as non-root users
- Database passwords are required
- Django SECRET_KEY must be set
- CORS is configured for your domain
- SQL injection protection via Django ORM
- XSS protection enabled

## Performance Tips

- Use SSD storage for database
- Allocate at least 2GB RAM for PostgreSQL
- Use Redis for caching (included)
- Enable gzip compression in Nginx (included)
- Monitor resource usage with `docker stats`

---

**No Traefik required!** This guide provides simple deployment options suitable for most use cases.

For questions or issues: https://github.com/Japsterr/DisplayDeck/issues