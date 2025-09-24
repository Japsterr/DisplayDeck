# DisplayDeck Deployment Guide with Portainer

This comprehensive guide covers deploying DisplayDeck using Docker containers with Portainer for container management.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Server Setup](#server-setup)
3. [Portainer Installation](#portainer-installation)
4. [DisplayDeck Deployment](#displaydeck-deployment)
5. [SSL Configuration](#ssl-configuration)
6. [Monitoring & Maintenance](#monitoring--maintenance)
7. [Backup Strategy](#backup-strategy)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware Requirements

**Minimum Configuration:**
- **CPU**: 2 cores, 2.4GHz
- **RAM**: 4GB
- **Storage**: 50GB SSD
- **Network**: Stable internet connection (100Mbps+)

**Recommended Configuration:**
- **CPU**: 4 cores, 3.0GHz+
- **RAM**: 8GB
- **Storage**: 100GB SSD
- **Network**: Dedicated server or VPS

**Production Configuration:**
- **CPU**: 8+ cores, 3.2GHz+
- **RAM**: 16GB+
- **Storage**: 200GB+ NVMe SSD
- **Network**: Load balancer, CDN integration

### Software Requirements

- **Operating System**: Ubuntu 20.04 LTS or later (recommended)
- **Docker**: Version 20.10+
- **Docker Compose**: Version 2.0+
- **Portainer**: Version 2.19+
- **Domain Name**: Configured with DNS pointing to server
- **SSL Certificate**: Let's Encrypt or commercial certificate

### Network Requirements

**Ports to Configure:**
- **80**: HTTP traffic (redirects to HTTPS)
- **443**: HTTPS traffic (main application)
- **9000**: Portainer web interface
- **9443**: Portainer HTTPS (if using SSL)
- **5432**: PostgreSQL (internal only)
- **6379**: Redis (internal only)

---

## Server Setup

### Initial Server Configuration

1. **Update System Packages:**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git unzip software-properties-common
```

2. **Install Docker:**
```bash
# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the stable repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER
```

3. **Verify Docker Installation:**
```bash
docker --version
docker compose version
docker run hello-world
```

4. **Configure Firewall:**
```bash
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 9000/tcp
sudo ufw enable
```

5. **Create Application Directory:**
```bash
mkdir -p /opt/displaydeck
cd /opt/displaydeck
```

---

## Portainer Installation

### Deploy Portainer Community Edition

1. **Create Portainer Volume:**
```bash
docker volume create portainer_data
```

2. **Deploy Portainer:**
```bash
docker run -d \
  --name portainer \
  --restart=always \
  -p 9000:9000 \
  -p 9443:9443 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

3. **Access Portainer Setup:**
- Open browser: `http://your-server-ip:9000`
- Create admin account (first time only)
- Choose "Docker" as the environment type
- Connect to local Docker socket

### Portainer Configuration

1. **Create DisplayDeck Environment:**
   - Go to **Environments** → **Add Environment**
   - Select **Docker Standalone**
   - Name: "DisplayDeck Production"
   - Environment URL: `unix:///var/run/docker.sock`

2. **Configure Registry (Optional):**
   - Go to **Registries** → **Add Registry**
   - For private images or GitHub Container Registry
   - Configure authentication if needed

3. **Set up Teams and Users:**
   - Go to **Users** → **Teams**
   - Create teams for different access levels
   - Assign appropriate permissions

---

## DisplayDeck Deployment

### Prepare Environment Files

1. **Create Directory Structure:**
```bash
mkdir -p /opt/displaydeck/{config,data,logs,backups}
cd /opt/displaydeck
```

2. **Create Production Environment File:**
```bash
cat > .env << 'EOF'
# DisplayDeck Production Configuration

# Application Settings
DEBUG=False
SECRET_KEY=your-super-secret-key-change-this-in-production
ALLOWED_HOSTS=your-domain.com,www.your-domain.com
CORS_ALLOWED_ORIGINS=https://your-domain.com,https://www.your-domain.com

# Database Configuration
POSTGRES_DB=displaydeck_prod
POSTGRES_USER=displaydeck
POSTGRES_PASSWORD=your-secure-database-password
DATABASE_URL=postgresql://displaydeck:your-secure-database-password@postgres:5432/displaydeck_prod

# Redis Configuration
REDIS_URL=redis://redis:6379/0
REDIS_PASSWORD=your-redis-password

# Email Configuration (for notifications)
EMAIL_HOST=smtp.your-provider.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=noreply@your-domain.com
EMAIL_HOST_PASSWORD=your-email-password
DEFAULT_FROM_EMAIL=DisplayDeck <noreply@your-domain.com>

# SSL and Security
USE_SSL=True
SECURE_SSL_REDIRECT=True
SECURE_HSTS_SECONDS=31536000
SECURE_HSTS_INCLUDE_SUBDOMAINS=True
SECURE_HSTS_PRELOAD=True
SECURE_CONTENT_TYPE_NOSNIFF=True
SECURE_BROWSER_XSS_FILTER=True
X_FRAME_OPTIONS=DENY

# Media and Static Files
MEDIA_URL=/media/
STATIC_URL=/static/
AWS_S3_BUCKET_NAME=your-s3-bucket-name
AWS_ACCESS_KEY_ID=your-aws-access-key
AWS_SECRET_ACCESS_KEY=your-aws-secret-key

# Monitoring and Logging
SENTRY_DSN=your-sentry-dsn-url
LOG_LEVEL=INFO

# Performance Settings
GUNICORN_WORKERS=4
GUNICORN_CONNECTIONS=1000
NGINX_WORKER_PROCESSES=auto
NGINX_WORKER_CONNECTIONS=1024
EOF
```

3. **Create Docker Compose Production File:**
```bash
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # PostgreSQL Database
  postgres:
    image: postgres:15-alpine
    container_name: displaydeck-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_INITDB_ARGS: "--encoding=UTF-8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./config/postgres.conf:/etc/postgresql/postgresql.conf:ro
      - ./logs/postgres:/var/log/postgresql
    command: >
      postgres -c config_file=/etc/postgresql/postgresql.conf
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - displaydeck-network

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: displaydeck-redis
    restart: unless-stopped
    command: >
      redis-server --appendonly yes --maxmemory 512mb 
      --maxmemory-policy allkeys-lru --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
      - ./config/redis.conf:/usr/local/etc/redis/redis.conf:ro
      - ./logs/redis:/var/log/redis
    healthcheck:
      test: ["CMD", "redis-cli", "--pass", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - displaydeck-network

  # Django Backend
  backend:
    image: ghcr.io/your-org/displaydeck-backend:latest
    container_name: displaydeck-backend
    restart: unless-stopped
    env_file: .env
    volumes:
      - backend_media:/app/media
      - backend_static:/app/staticfiles
      - ./logs/backend:/app/logs
      - ./backups:/app/backups
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    networks:
      - displaydeck-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.backend.rule=Host(`api.your-domain.com`)"
      - "traefik.http.routers.backend.tls=true"
      - "traefik.http.routers.backend.tls.certresolver=letsencrypt"

  # React Frontend
  frontend:
    image: ghcr.io/your-org/displaydeck-frontend:latest
    container_name: displaydeck-frontend
    restart: unless-stopped
    environment:
      - VITE_API_BASE_URL=https://api.your-domain.com
      - VITE_WS_URL=wss://api.your-domain.com
    depends_on:
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - displaydeck-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`your-domain.com`)"
      - "traefik.http.routers.frontend.tls=true"
      - "traefik.http.routers.frontend.tls.certresolver=letsencrypt"

  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: displaydeck-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./config/ssl:/etc/nginx/ssl:ro
      - backend_static:/usr/share/nginx/static:ro
      - backend_media:/usr/share/nginx/media:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - backend
      - frontend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - displaydeck-network

  # Traefik Load Balancer (Alternative to Nginx)
  traefik:
    image: traefik:v3.0
    container_name: displaydeck-traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Traefik dashboard
    command:
      - "--api.dashboard=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.letsencrypt.acme.email=admin@your-domain.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./config/acme.json:/acme.json
    networks:
      - displaydeck-network
    profiles:
      - traefik  # Enable with --profile traefik

  # Monitoring - Prometheus
  prometheus:
    image: prom/prometheus:latest
    container_name: displaydeck-prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    networks:
      - displaydeck-network
    profiles:
      - monitoring

  # Monitoring - Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: displaydeck-grafana
    restart: unless-stopped
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD:-admin}
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/grafana:/etc/grafana/provisioning
    networks:
      - displaydeck-network
    profiles:
      - monitoring

volumes:
  postgres_data:
    driver: local
  redis_data:
    driver: local
  backend_media:
    driver: local
  backend_static:
    driver: local
  prometheus_data:
    driver: local
  grafana_data:
    driver: local

networks:
  displaydeck-network:
    driver: bridge
EOF
```

### Deploy via Portainer

1. **Access Portainer Dashboard:**
   - Navigate to `http://your-server-ip:9000`
   - Login with admin credentials

2. **Create New Stack:**
   - Go to **Stacks** → **Add Stack**
   - Name: "DisplayDeck Production"
   - Build method: **Repository**
   - Repository URL: Your Git repository URL
   - Compose path: `deployment/docker/docker-compose.prod.yml`

3. **Configure Environment Variables:**
   - Add all variables from your `.env` file
   - Use Portainer's secret management for sensitive values
   - Enable **Auto-update** if desired

4. **Deploy Stack:**
   - Review configuration
   - Click **Deploy the stack**
   - Monitor deployment logs

### Verify Deployment

1. **Check Container Status:**
   - All containers should show "running" status
   - Review logs for any errors
   - Verify health checks are passing

2. **Test Application:**
   - Backend API: `https://api.your-domain.com/health/`
   - Frontend: `https://your-domain.com`
   - Admin dashboard: `https://your-domain.com/admin/`

3. **Database Migration:**
```bash
# Run initial database setup
docker exec -it displaydeck-backend python manage.py migrate
docker exec -it displaydeck-backend python manage.py createsuperuser
docker exec -it displaydeck-backend python manage.py collectstatic --noinput
```

---

## SSL Configuration

### Let's Encrypt with Traefik

If using Traefik (enabled with `--profile traefik`):

1. **Configure DNS:**
   - Point your domain to server IP
   - Set up CNAME for `api.your-domain.com`

2. **Update Traefik Configuration:**
   - Certificates are automatically obtained
   - Monitor certificate renewal logs

### Manual SSL with Nginx

If using Nginx with custom certificates:

1. **Install Certbot:**
```bash
sudo apt install certbot python3-certbot-nginx
```

2. **Obtain Certificate:**
```bash
sudo certbot --nginx -d your-domain.com -d www.your-domain.com -d api.your-domain.com
```

3. **Configure Auto-renewal:**
```bash
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

### SSL Best Practices

1. **Security Headers:**
   - HSTS enabled
   - Content Security Policy configured
   - X-Frame-Options set to DENY

2. **Certificate Monitoring:**
   - Set up alerts for certificate expiration
   - Test renewal process regularly
   - Monitor SSL Labs rating

---

## Monitoring & Maintenance

### Portainer Monitoring Features

1. **Container Monitoring:**
   - Real-time resource usage
   - Log aggregation and search
   - Health check status
   - Performance metrics

2. **Stack Management:**
   - Easy updates and rollbacks
   - Environment variable management
   - Volume and network oversight
   - Scaling capabilities

3. **Alerts and Notifications:**
   - Configure webhook notifications
   - Set up email alerts for failures
   - Monitor resource thresholds
   - Custom alert rules

### Performance Monitoring

1. **Enable Prometheus/Grafana:**
```bash
docker compose --profile monitoring up -d
```

2. **Access Monitoring:**
   - Prometheus: `http://your-server-ip:9090`
   - Grafana: `http://your-server-ip:3001`
   - Login: admin/admin (change default password)

3. **Key Metrics to Monitor:**
   - Response times and throughput
   - Database connection pools
   - Memory and CPU usage
   - Disk space and I/O
   - Error rates and logs

### Log Management

1. **Centralized Logging:**
   - All logs stored in `/opt/displaydeck/logs/`
   - Structured JSON logging enabled
   - Log rotation configured

2. **Log Analysis:**
```bash
# View recent backend logs
docker logs displaydeck-backend --tail 100 -f

# Search for errors
grep -r "ERROR" /opt/displaydeck/logs/

# Monitor real-time logs
tail -f /opt/displaydeck/logs/backend/django.log
```

### Regular Maintenance Tasks

#### Daily Tasks (Automated)
- [ ] Health check monitoring
- [ ] Backup verification
- [ ] Log rotation
- [ ] Security updates check

#### Weekly Tasks
- [ ] Review performance metrics
- [ ] Check disk space usage
- [ ] Update Docker images
- [ ] Review error logs

#### Monthly Tasks
- [ ] Security audit
- [ ] Backup restoration test
- [ ] Performance optimization review
- [ ] Capacity planning assessment

---

## Backup Strategy

### Database Backups

1. **Automated PostgreSQL Backups:**
```bash
# Create backup script
cat > /opt/displaydeck/scripts/backup-db.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/displaydeck/backups"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="displaydeck_prod"

# Create backup
docker exec displaydeck-postgres pg_dump -U displaydeck -d $DB_NAME > "$BACKUP_DIR/db_backup_$DATE.sql"

# Compress backup
gzip "$BACKUP_DIR/db_backup_$DATE.sql"

# Keep only last 30 days of backups
find "$BACKUP_DIR" -name "db_backup_*.sql.gz" -mtime +30 -delete

echo "Database backup completed: db_backup_$DATE.sql.gz"
EOF

chmod +x /opt/displaydeck/scripts/backup-db.sh
```

2. **Schedule Backups:**
```bash
# Add to crontab
echo "0 2 * * * /opt/displaydeck/scripts/backup-db.sh" | crontab -
```

### Volume Backups

1. **Create Volume Backup Script:**
```bash
cat > /opt/displaydeck/scripts/backup-volumes.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/displaydeck/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup media files
tar -czf "$BACKUP_DIR/media_backup_$DATE.tar.gz" -C /var/lib/docker/volumes/displaydeck_backend_media/_data .

# Backup static files
tar -czf "$BACKUP_DIR/static_backup_$DATE.tar.gz" -C /var/lib/docker/volumes/displaydeck_backend_static/_data .

# Clean old backups
find "$BACKUP_DIR" -name "*_backup_*.tar.gz" -mtime +7 -delete

echo "Volume backups completed: $DATE"
EOF

chmod +x /opt/displaydeck/scripts/backup-volumes.sh
```

### Off-site Backup Storage

1. **AWS S3 Integration:**
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS credentials
aws configure

# Sync backups to S3
aws s3 sync /opt/displaydeck/backups/ s3://your-backup-bucket/displaydeck/
```

2. **Automated Off-site Sync:**
```bash
cat > /opt/displaydeck/scripts/sync-backups.sh << 'EOF'
#!/bin/bash
# Sync recent backups to S3
aws s3 sync /opt/displaydeck/backups/ s3://your-backup-bucket/displaydeck/ --delete

# Verify sync
aws s3 ls s3://your-backup-bucket/displaydeck/ --recursive --human-readable --summarize
EOF
```

### Backup Restoration

1. **Database Restoration:**
```bash
# Stop backend service
docker compose stop backend

# Restore database
gunzip < /opt/displaydeck/backups/db_backup_YYYYMMDD_HHMMSS.sql.gz | \
docker exec -i displaydeck-postgres psql -U displaydeck -d displaydeck_prod

# Restart services
docker compose up -d
```

2. **Volume Restoration:**
```bash
# Stop services
docker compose stop

# Restore media files
tar -xzf /opt/displaydeck/backups/media_backup_YYYYMMDD_HHMMSS.tar.gz \
  -C /var/lib/docker/volumes/displaydeck_backend_media/_data

# Restart services
docker compose up -d
```

---

## Troubleshooting

### Common Issues and Solutions

#### Container Startup Issues

**Problem**: Container fails to start
```bash
# Check logs
docker logs displaydeck-backend

# Common solutions:
1. Verify environment variables
2. Check file permissions
3. Ensure dependencies are running
4. Review Docker Compose syntax
```

**Problem**: Database connection failed
```bash
# Verify PostgreSQL is running
docker exec displaydeck-postgres pg_isready -U displaydeck

# Check database logs
docker logs displaydeck-postgres

# Test connectivity
docker exec displaydeck-backend python manage.py dbshell
```

#### Performance Issues

**Problem**: Slow response times
1. **Check resource usage:**
```bash
docker stats
```

2. **Review logs for bottlenecks:**
```bash
docker logs displaydeck-backend | grep "SLOW"
```

3. **Database optimization:**
```bash
# Run database optimization
docker exec displaydeck-backend python manage.py optimize_database
```

**Problem**: High memory usage
1. **Identify memory-hungry containers:**
```bash
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

2. **Adjust resource limits:**
```yaml
# Add to docker-compose.yml
deploy:
  resources:
    limits:
      memory: 512M
    reservations:
      memory: 256M
```

#### SSL Certificate Issues

**Problem**: Certificate not working
1. **Check certificate status:**
```bash
curl -I https://your-domain.com
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

2. **Renew certificate:**
```bash
sudo certbot renew --force-renewal
```

3. **Restart Nginx:**
```bash
docker compose restart nginx
```

#### Portainer Issues

**Problem**: Cannot access Portainer dashboard
1. **Check if Portainer is running:**
```bash
docker ps | grep portainer
```

2. **Restart Portainer:**
```bash
docker restart portainer
```

3. **Check firewall settings:**
```bash
sudo ufw status
```

### Emergency Recovery Procedures

#### System Recovery Checklist

1. **Immediate Assessment:**
   - [ ] Identify scope of the issue
   - [ ] Check system resources (disk, memory, CPU)
   - [ ] Verify external dependencies (DNS, SSL)
   - [ ] Review recent changes

2. **Service Recovery:**
   - [ ] Stop all containers: `docker compose down`
   - [ ] Check for corrupted volumes
   - [ ] Restore from latest backup if needed
   - [ ] Start services incrementally

3. **Data Recovery:**
   - [ ] Identify data integrity issues
   - [ ] Restore database from backup
   - [ ] Verify data consistency
   - [ ] Test application functionality

#### Disaster Recovery Plan

1. **Full System Rebuild:**
   - Provision new server with same specifications
   - Install Docker and Portainer
   - Restore from off-site backups
   - Update DNS records if IP changed
   - Test all functionality

2. **Rollback Procedures:**
   - Keep previous Docker image tags
   - Maintain database backup before updates
   - Document rollback procedures
   - Test rollback process regularly

### Support and Escalation

#### Internal Support Process
1. Check logs and metrics first
2. Review troubleshooting guide
3. Search community forums
4. Contact DisplayDeck support if needed

#### Contact Information
- **Technical Support**: support@displaydeck.com
- **Emergency Hotline**: 1-800-DISPLAY
- **Community Forum**: https://community.displaydeck.com
- **Documentation**: https://docs.displaydeck.com

#### Information to Provide
- Server specifications and OS version
- Docker and Portainer versions
- Error messages and logs
- Steps to reproduce the issue
- Recent changes or updates

---

## Appendix

### Useful Commands Reference

#### Docker Management
```bash
# View all containers
docker ps -a

# View logs for specific service
docker compose logs backend

# Execute command in container
docker exec -it displaydeck-backend bash

# Update specific service
docker compose up -d --no-deps backend

# View resource usage
docker stats

# Clean up unused resources
docker system prune -a
```

#### Database Operations
```bash
# Access database shell
docker exec -it displaydeck-postgres psql -U displaydeck -d displaydeck_prod

# Create database backup
docker exec displaydeck-postgres pg_dump -U displaydeck displaydeck_prod > backup.sql

# Monitor database performance
docker exec displaydeck-postgres psql -U displaydeck -d displaydeck_prod -c "SELECT * FROM pg_stat_activity;"
```

#### System Monitoring
```bash
# Check disk usage
df -h

# Monitor system resources
htop

# View system logs
journalctl -u docker.service -f

# Network connectivity test
curl -I http://localhost/health
```

### Configuration Templates

#### Nginx Configuration Template
```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com www.your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    location / {
        proxy_pass http://frontend:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /api/ {
        proxy_pass http://backend:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

#### Environment Variables Template
```bash
# Copy and customize for your environment
cp .env.example .env
nano .env

# Required variables:
SECRET_KEY=your-unique-secret-key
POSTGRES_PASSWORD=secure-database-password
ALLOWED_HOSTS=your-domain.com,api.your-domain.com
```

---

*Last Updated: September 2024*  
*Document Version: 1.0.0*

For the most current deployment procedures, visit: [docs.displaydeck.com/deployment](https://docs.displaydeck.com/deployment)