# DisplayDeck Digital Menu Management System

## Quick Start Guide

Welcome to DisplayDeck! This guide will help you set up and deploy the complete digital menu management system for your restaurant or cafe.

### What is DisplayDeck?

DisplayDeck is a comprehensive digital menu management system that includes:

- **Web Dashboard**: Full administrative interface for managing menus, displays, and business settings
- **Mobile App**: On-the-go management and display control from your smartphone
- **Android TV Display Client**: Digital menu displays for customer-facing screens
- **Real-time Sync**: Instant updates across all displays when you change menu items or prices

### System Requirements

#### For Development
- **Backend**: Python 3.11+, PostgreSQL 13+, Redis 6+
- **Frontend**: Node.js 18+, npm/yarn
- **Mobile**: Node.js 18+, Expo CLI, Android Studio (optional)
- **Android TV**: Android Studio, Android SDK 26+, Kotlin support

#### For Production Deployment
- **Server**: Linux server with Docker and Docker Compose
- **Domain**: Custom domain with SSL certificate capability
- **Database**: PostgreSQL 13+ (managed service recommended)
- **Cache**: Redis 6+ (managed service recommended)
- **Storage**: File storage for media assets (S3 compatible)

### Quick Deployment Options

## Option 1: Development Setup (Recommended for Testing)

### Prerequisites
1. Install Docker and Docker Compose
2. Clone the repository
3. Set up environment variables

### Steps

1. **Clone and Setup**
```bash
git clone <repository-url> displaydeck
cd displaydeck
```

2. **Environment Configuration**
```bash
# Copy environment templates
cp .env.example .env
cp backend/src/core/settings/.env.example backend/src/core/settings/.env
cp frontend/.env.example frontend/.env
cp mobile/.env.example mobile/.env
```

3. **Start Development Environment**
```bash
# Start all services with Docker Compose
docker-compose -f deployment/docker/docker-compose.dev.yml up -d

# Wait for services to be healthy (about 2 minutes)
docker-compose -f deployment/docker/docker-compose.dev.yml ps
```

4. **Initialize Database**
```bash
# Run migrations and create superuser
docker-compose -f deployment/docker/docker-compose.dev.yml exec backend python manage.py migrate
docker-compose -f deployment/docker/docker-compose.dev.yml exec backend python manage.py createsuperuser
```

5. **Access Applications**
- **Web Dashboard**: http://localhost:3000
- **API Documentation**: http://localhost:8000/api/docs/
- **Database Admin**: http://localhost:5050 (pgAdmin)
- **Redis GUI**: http://localhost:8081
- **Email Testing**: http://localhost:8025 (Mailhog)

## Option 2: Production Deployment with Portainer

### Prerequisites
1. Linux server with Docker Swarm initialized
2. Portainer installed and running
3. Domain name pointing to your server

### Steps

1. **Prepare Server**
```bash
# Initialize Docker Swarm (if not already done)
docker swarm init

# Create Docker secrets
echo "your-secret-key-here" | docker secret create django_secret_key -
echo "your-db-password" | docker secret create postgres_password -
echo "your-redis-password" | docker secret create redis_password -
echo "grafana-admin-password" | docker secret create grafana_password -
```

2. **Deploy Stack via Portainer**
- Upload `deployment/docker/docker-stack.yml` to Portainer
- Set environment variables:
  - `DOMAIN_NAME=yourdomain.com`
  - `LETSENCRYPT_EMAIL=admin@yourdomain.com`
- Deploy the stack

3. **Initialize Application**
```bash
# Find backend service container
docker ps | grep backend

# Run initial setup
docker exec <backend-container-id> python manage.py migrate
docker exec <backend-container-id> python manage.py createsuperuser
docker exec <backend-container-id> python manage.py collectstatic --noinput
```

4. **Access Applications**
- **Web Dashboard**: https://yourdomain.com
- **API Documentation**: https://yourdomain.com/api/docs/
- **Monitoring**: https://yourdomain.com/grafana/

## Initial Configuration

### 1. Create Your First Business

1. Access the web dashboard at your domain
2. Log in with your superuser account
3. Navigate to "Businesses" and click "Add Business"
4. Fill in your restaurant details:
   - Business name
   - Type (Fast Food, Cafe, etc.)
   - Contact information
   - Address

### 2. Set Up Your First Menu

1. Go to "Menu Management"
2. Click "Create New Menu"
3. Add menu categories (e.g., "Burgers", "Sides", "Drinks")
4. Add menu items with:
   - Names and descriptions
   - Prices
   - Images (optional)
   - Dietary information

### 3. Pair Your First Display

#### Option A: Android TV Display
1. Install the DisplayDeck Android TV app on your Android TV device
2. Open the app and note the pairing QR code
3. In the web dashboard, go to "Display Management"
4. Click "Add Display" and scan the QR code
5. Assign a menu to the display

#### Option B: Web Display (for testing)
1. Open a browser in full-screen mode on your display device
2. Navigate to: `https://yourdomain.com/display/?token=<display-token>`
3. The display token can be found in Display Management

### 4. Mobile App Setup

1. Install the DisplayDeck mobile app from the app store
2. Log in with your business account
3. You can now manage menus and displays from your phone

## User Management

### Roles and Permissions

- **Owner**: Full access to business settings, users, and all features
- **Manager**: Menu management, display control, analytics viewing
- **Staff**: View-only access to menus and basic display status

### Inviting Users

1. Go to "User Management" in the web dashboard
2. Click "Invite User"
3. Enter email and select role
4. User will receive an invitation email

## Advanced Configuration

### Environment Variables

#### Backend Environment Variables
```bash
# Database
DB_HOST=postgres
DB_NAME=displaydeck_prod
DB_USER=displaydeck_user
DB_PASSWORD=<from-docker-secret>

# Redis
REDIS_URL=redis://redis:6379/0

# Security
SECRET_KEY=<from-docker-secret>
DEBUG=False
ALLOWED_HOSTS=yourdomain.com

# Email
EMAIL_HOST=smtp.yourprovider.com
EMAIL_PORT=587
EMAIL_HOST_USER=noreply@yourdomain.com
EMAIL_HOST_PASSWORD=<your-email-password>
EMAIL_USE_TLS=True

# Storage (S3 compatible)
AWS_ACCESS_KEY_ID=<your-access-key>
AWS_SECRET_ACCESS_KEY=<your-secret-key>
AWS_STORAGE_BUCKET_NAME=displaydeck-media
AWS_S3_REGION_NAME=us-east-1
```

#### Frontend Environment Variables
```bash
REACT_APP_API_URL=https://yourdomain.com/api/v1
REACT_APP_WS_URL=wss://yourdomain.com/ws
REACT_APP_ENVIRONMENT=production
```

#### Mobile Environment Variables
```bash
EXPO_API_URL=https://yourdomain.com/api/v1
EXPO_WS_URL=wss://yourdomain.com/ws
EXPO_ENVIRONMENT=production
```

### SSL Certificate Setup

The production deployment automatically handles SSL certificates via Let's Encrypt. Ensure:

1. Your domain points to the server IP
2. Ports 80 and 443 are open
3. The `LETSENCRYPT_EMAIL` environment variable is set

### Database Backups

Automatic backups are configured in the production stack:

- **Schedule**: Daily at 2 AM UTC
- **Retention**: 30 days
- **Storage**: Local and S3 (if configured)

Manual backup:
```bash
# Create backup
docker exec <postgres-container> pg_dump -U displaydeck_user displaydeck_prod > backup.sql

# Restore backup
docker exec -i <postgres-container> psql -U displaydeck_user displaydeck_prod < backup.sql
```

### Monitoring and Logs

The production deployment includes comprehensive monitoring:

- **Prometheus**: Metrics collection
- **Grafana**: Visualization dashboards
- **Loki**: Log aggregation
- **Health checks**: Automatic service health monitoring

Access monitoring at: `https://yourdomain.com/grafana/`

Default credentials:
- Username: admin
- Password: (from grafana_password secret)

### Scaling

The system is designed for horizontal scaling:

#### Backend Scaling
```bash
# Scale backend services
docker service scale displaydeck_backend=3
docker service scale displaydeck_celery-worker=2
```

#### Database Scaling
- Use managed PostgreSQL services (AWS RDS, Google Cloud SQL)
- Configure read replicas for improved performance
- Use connection pooling (PgBouncer)

#### Load Balancing
- Nginx handles load balancing automatically
- For high traffic, use external load balancers (AWS ALB, Cloudflare)

## Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check service status
docker-compose -f deployment/docker/docker-compose.dev.yml ps

# View logs
docker-compose -f deployment/docker/docker-compose.dev.yml logs backend
docker-compose -f deployment/docker/docker-compose.dev.yml logs postgres
```

#### Database Connection Issues
```bash
# Test database connection
docker-compose -f deployment/docker/docker-compose.dev.yml exec backend python manage.py dbshell

# Reset database (development only)
docker-compose -f deployment/docker/docker-compose.dev.yml down -v
docker-compose -f deployment/docker/docker-compose.dev.yml up -d
```

#### SSL Certificate Issues
```bash
# Check certificate status
docker logs <nginx-container>
docker logs <letsencrypt-container>

# Force certificate renewal
docker exec <letsencrypt-container> /app/force_renew
```

#### Display Connection Issues
1. Check display token validity in admin panel
2. Verify network connectivity
3. Check WebSocket connection logs
4. Restart display app

### Performance Optimization

#### Database Optimization
```sql
-- Add indexes for better performance
CREATE INDEX idx_menu_items_category ON menu_items(category_id);
CREATE INDEX idx_displays_business ON displays(business_id);
CREATE INDEX idx_analytics_timestamp ON analytics_events(timestamp);
```

#### Frontend Optimization
- Enable gzip compression
- Use CDN for static assets
- Implement service workers for offline functionality

#### Mobile App Optimization
- Enable code splitting
- Use image optimization
- Implement efficient caching strategies

## Security Considerations

### Production Security Checklist

- [ ] Change all default passwords
- [ ] Use strong, unique passwords for all services
- [ ] Enable firewall with only necessary ports open
- [ ] Regular security updates for all components
- [ ] Use managed database services when possible
- [ ] Enable backup encryption
- [ ] Implement API rate limiting
- [ ] Use HTTPS everywhere
- [ ] Regular security audits

### API Security

- JWT tokens expire after 1 hour
- Refresh tokens expire after 7 days
- Rate limiting: 1000 requests/hour per user
- CORS properly configured for your domains
- Input validation on all endpoints

## Support and Maintenance

### Regular Maintenance Tasks

#### Weekly
- Review system logs
- Check backup status
- Monitor system performance
- Update security patches

#### Monthly
- Database maintenance (VACUUM, ANALYZE)
- Clean up old log files
- Review user access permissions
- Update dependencies

#### Quarterly
- Full system backup test
- Security audit
- Performance optimization review
- Capacity planning

### Getting Help

- **Documentation**: Check this guide and API documentation
- **Logs**: Always check application logs first
- **Community**: Join our community forum
- **Support**: Contact support@displaydeck.com for enterprise support

## License and Legal

DisplayDeck is released under the MIT License. See LICENSE file for details.

### Data Privacy

DisplayDeck is designed with privacy in mind:
- Multi-tenant data isolation
- Encryption in transit and at rest
- GDPR compliance features
- Data retention policies

### Third-Party Services

The system integrates with:
- Let's Encrypt for SSL certificates
- Cloud storage providers for media assets
- Email services for notifications
- Monitoring services for system health

Ensure compliance with their terms of service and privacy policies.

---

**Congratulations!** You now have a fully functional DisplayDeck digital menu management system. For advanced configurations and customizations, refer to the detailed documentation in the `/docs` directory.