# Environment Configuration Guide for DisplayDeck

This directory contains environment configuration files for different deployment scenarios.

## Files

### `development.env`
- Used for local development
- Contains permissive settings for easy setup
- Uses SQLite by default for simplicity
- Includes debug settings and development tools

### `production.env.template`
- Template for production environment
- Contains security-focused settings
- Requires external services (PostgreSQL, Redis)
- Uses Docker secrets for sensitive values

### `staging.env.template`
- Template for staging environment
- Similar to production but with relaxed security for testing
- Useful for pre-production validation

## Usage

### Development Setup

1. Copy the development environment file:
   ```bash
   cp deployment/env/development.env backend/src/.env
   ```

2. Adjust any local settings as needed (database, ports, etc.)

3. Start development services:
   ```bash
   cd deployment/docker
   docker-compose -f docker-compose.dev.yml up
   ```

### Production Setup

1. Copy and customize the production template:
   ```bash
   cp deployment/env/production.env.template /path/to/production/.env
   ```

2. Update all required values:
   - `SECRET_KEY`: Generate a secure random key
   - `DOMAIN_NAME`: Your actual domain
   - `LETSENCRYPT_EMAIL`: Valid email for SSL certificates
   - Database credentials
   - Email settings
   - S3/CDN settings (if used)

3. Create Docker secrets for sensitive values:
   ```bash
   # Create secrets
   echo "your-secret-key" | docker secret create django_secret_key -
   echo "your-db-password" | docker secret create postgres_password -
   echo "your-redis-password" | docker secret create redis_password -
   ```

4. Deploy using Docker Stack:
   ```bash
   docker stack deploy -c docker-stack.yml displaydeck
   ```

## Environment Variables Reference

### Core Settings
- `SECRET_KEY`: Django secret key (required)
- `DEBUG`: Enable debug mode (False for production)
- `ALLOWED_HOSTS`: Comma-separated list of allowed hosts
- `DOMAIN_NAME`: Primary domain name
- `LETSENCRYPT_EMAIL`: Email for SSL certificate notifications

### Database
- `DB_HOST`: Database server hostname
- `DB_PORT`: Database server port
- `DB_NAME`: Database name
- `DB_USER`: Database username
- `DB_PASSWORD`: Database password (use Docker secrets in production)

### Cache and Messaging
- `REDIS_URL`: Redis connection URL
- `REDIS_PASSWORD`: Redis password (use Docker secrets in production)

### Email
- `EMAIL_BACKEND`: Email backend class
- `EMAIL_HOST`: SMTP server hostname
- `EMAIL_PORT`: SMTP server port
- `EMAIL_USE_TLS`: Enable TLS encryption
- `EMAIL_HOST_USER`: SMTP username
- `EMAIL_HOST_PASSWORD`: SMTP password (use Docker secrets in production)

### Security
- `SECURE_SSL_REDIRECT`: Force HTTPS redirects
- `SECURE_HSTS_SECONDS`: HTTP Strict Transport Security duration
- `CORS_ALLOW_ALL_ORIGINS`: Allow all CORS origins (dev only)
- `CORS_ALLOWED_ORIGINS`: Comma-separated allowed origins

### Storage
- `MEDIA_STORAGE`: Media storage backend (local/s3)
- `STATIC_STORAGE`: Static file storage backend (local/s3/cdn)
- `AWS_STORAGE_BUCKET_NAME`: S3 bucket for media files
- `AWS_S3_REGION_NAME`: AWS region
- `CDN_URL`: CDN base URL for static files

### Monitoring
- `LOG_LEVEL`: Logging level (DEBUG/INFO/WARNING/ERROR/CRITICAL)
- `SENTRY_DSN`: Sentry error tracking DSN
- `SENTRY_ENVIRONMENT`: Sentry environment name

### Backup
- `BACKUP_SCHEDULE`: Cron schedule for backups
- `BACKUP_RETENTION_DAYS`: Days to keep daily backups
- `BACKUP_S3_BUCKET`: S3 bucket for backup storage

### Feature Flags
- `ENABLE_SUBDOMAIN_TENANTS`: Enable subdomain-based tenant detection
- `ENABLE_DISPLAY_ANALYTICS`: Enable display analytics tracking
- `ENABLE_REAL_TIME_UPDATES`: Enable WebSocket real-time updates

## Security Best Practices

1. **Never commit sensitive values**: Use Docker secrets or environment-specific files
2. **Rotate credentials regularly**: Especially API keys and passwords
3. **Use strong passwords**: Generate random passwords for all services
4. **Enable SSL/TLS**: Always use HTTPS in production
5. **Restrict CORS origins**: Only allow necessary domains
6. **Monitor access logs**: Watch for suspicious activity
7. **Keep dependencies updated**: Regularly update all packages

## Frontend Environment Variables

The frontend applications (React, React Native, Android TV) also need environment configuration:

### React Frontend (.env.local)
```bash
REACT_APP_API_URL=https://yourdomain.com/api/v1
REACT_APP_WS_URL=wss://yourdomain.com/ws
REACT_APP_ENVIRONMENT=production
```

### React Native Mobile (.env)
```bash
EXPO_API_URL=https://yourdomain.com/api/v1
EXPO_WS_URL=wss://yourdomain.com/ws
EXPO_ENVIRONMENT=production
```

### Android TV (local.properties)
```bash
android.tv.api.url=https://yourdomain.com/api/v1
android.tv.ws.url=wss://yourdomain.com/ws
android.tv.environment=production
```

## Troubleshooting

### Common Issues

1. **Database connection fails**: Check DB credentials and network connectivity
2. **Redis connection fails**: Verify Redis service is running and accessible
3. **SSL certificate issues**: Check domain DNS and Let's Encrypt logs
4. **CORS errors**: Verify CORS_ALLOWED_ORIGINS includes your frontend domain
5. **Static files not loading**: Check STATIC_URL and file permissions

### Debug Commands

```bash
# Check Docker services
docker service ls

# View service logs
docker service logs displaydeck_backend

# Test database connection
docker exec -it $(docker ps -q -f name=postgres) psql -U displaydeck_user -d displaydeck_prod

# Test Redis connection
docker exec -it $(docker ps -q -f name=redis) redis-cli ping

# Check SSL certificate
openssl x509 -in /etc/letsencrypt/live/yourdomain.com/cert.pem -text -noout
```