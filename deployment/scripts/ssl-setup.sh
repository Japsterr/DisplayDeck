#!/bin/bash

# SSL Certificate Setup Script for DisplayDeck
# Automates Let's Encrypt SSL certificate generation and renewal

set -euo pipefail

# Configuration
DOMAIN_NAME="${DOMAIN_NAME:-displaydeck.com}"
EMAIL="${LETSENCRYPT_EMAIL:-admin@displaydeck.com}"
WEBROOT="/var/www/html"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN_NAME"
NGINX_CONF_DIR="/etc/nginx/conf.d"
BACKUP_DIR="/backup/ssl"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Install certbot if not present
install_certbot() {
    if ! command -v certbot &> /dev/null; then
        log "Installing certbot..."
        
        if command -v apt-get &> /dev/null; then
            # Ubuntu/Debian
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
        elif command -v yum &> /dev/null; then
            # CentOS/RHEL
            yum install -y certbot python3-certbot-nginx
        elif command -v apk &> /dev/null; then
            # Alpine Linux
            apk add --no-cache certbot certbot-nginx
        else
            error "Unsupported package manager. Please install certbot manually."
            exit 1
        fi
        
        log "Certbot installed successfully"
    else
        info "Certbot is already installed"
    fi
}

# Backup existing certificates
backup_certificates() {
    if [[ -d "$CERT_PATH" ]]; then
        log "Backing up existing certificates..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$CERT_PATH" "$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S)"
        log "Certificates backed up to $BACKUP_DIR"
    fi
}

# Generate initial nginx configuration for HTTP challenge
create_initial_nginx_config() {
    log "Creating initial nginx configuration for HTTP challenge..."
    
    cat > "$NGINX_CONF_DIR/ssl-challenge.conf" << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    
    # ACME challenge location
    location /.well-known/acme-challenge/ {
        root $WEBROOT;
        try_files \$uri =404;
    }
    
    # Redirect all other traffic to HTTPS (after SSL is set up)
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF

    # Create webroot directory
    mkdir -p "$WEBROOT/.well-known/acme-challenge"
    
    # Test nginx configuration
    if nginx -t; then
        systemctl reload nginx || service nginx reload
        log "Nginx configuration updated and reloaded"
    else
        error "Nginx configuration test failed"
        exit 1
    fi
}

# Generate SSL certificate
generate_certificate() {
    log "Generating SSL certificate for $DOMAIN_NAME..."
    
    # Create webroot if it doesn't exist
    mkdir -p "$WEBROOT"
    
    # Generate certificate
    certbot certonly \
        --webroot \
        --webroot-path="$WEBROOT" \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --domains "$DOMAIN_NAME,www.$DOMAIN_NAME" \
        --non-interactive \
        --expand
    
    if [[ $? -eq 0 ]]; then
        log "SSL certificate generated successfully"
    else
        error "Failed to generate SSL certificate"
        exit 1
    fi
}

# Create production nginx configuration with SSL
create_ssl_nginx_config() {
    log "Creating production nginx configuration with SSL..."
    
    cat > "$NGINX_CONF_DIR/displaydeck-ssl.conf" << 'EOF'
# Rate limiting
limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

# Upstream backends
upstream backend {
    least_conn;
    server backend:8000 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

upstream frontend {
    least_conn;
    server frontend:3000 max_fails=3 fail_timeout=30s;
    keepalive 32;
}

# HTTP to HTTPS redirect
server {
    listen 80;
    server_name DOMAIN_NAME www.DOMAIN_NAME;
    
    # ACME challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files $uri =404;
    }
    
    # Redirect all other traffic to HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    server_name DOMAIN_NAME www.DOMAIN_NAME;
    
    # SSL Configuration
    ssl_certificate /etc/letsencrypt/live/DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/DOMAIN_NAME/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt/live/DOMAIN_NAME/chain.pem;
    
    # SSL Security
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_timeout 10m;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;
    
    # HSTS
    add_header Strict-Transport-Security "max-age=63072000" always;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Client settings
    client_max_body_size 100M;
    client_body_timeout 60s;
    client_header_timeout 60s;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    # Frontend routes
    location / {
        proxy_pass http://frontend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }

    # API routes
    location /api/ {
        # Rate limiting
        limit_req zone=api burst=20 nodelay;
        
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Authentication routes (stricter rate limiting)
    location /api/v1/auth/ {
        limit_req zone=login burst=5 nodelay;
        
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket routes
    location /ws/ {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # WebSocket specific timeouts
        proxy_connect_timeout 7d;
        proxy_send_timeout 7d;
        proxy_read_timeout 7d;
    }

    # Django admin
    location /admin/ {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static files
    location /static/ {
        alias /var/www/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
        
        # Compress static files
        location ~* \.(js|css)$ {
            gzip_static on;
        }
    }

    # Media files
    location /media/ {
        alias /var/www/media/;
        expires 30d;
        add_header Cache-Control "public";
        
        # Security for uploaded files
        location ~* \.(php|pl|py|jsp|asp|sh|cgi)$ {
            deny all;
        }
    }

    # Health check
    location /health {
        proxy_pass http://backend;
        proxy_set_header Host $host;
        access_log off;
    }

    # Block access to sensitive files
    location ~ /\. {
        deny all;
    }
    
    location ~ /\.ht {
        deny all;
    }
}
EOF

    # Replace domain placeholder
    sed -i "s/DOMAIN_NAME/$DOMAIN_NAME/g" "$NGINX_CONF_DIR/displaydeck-ssl.conf"
    
    # Remove the challenge-only config
    rm -f "$NGINX_CONF_DIR/ssl-challenge.conf"
    
    # Test nginx configuration
    if nginx -t; then
        systemctl reload nginx || service nginx reload
        log "SSL nginx configuration updated and reloaded"
    else
        error "SSL nginx configuration test failed"
        exit 1
    fi
}

# Setup automatic renewal
setup_renewal() {
    log "Setting up automatic certificate renewal..."
    
    # Create renewal script
    cat > "/usr/local/bin/renew-ssl.sh" << 'EOF'
#!/bin/bash
# SSL Certificate Renewal Script

# Renew certificates
certbot renew --quiet --no-self-upgrade

# Reload nginx if certificates were renewed
if [[ $? -eq 0 ]]; then
    systemctl reload nginx || service nginx reload
    echo "$(date): SSL certificates renewed and nginx reloaded" >> /var/log/ssl-renewal.log
fi
EOF

    chmod +x /usr/local/bin/renew-ssl.sh
    
    # Add cron job for renewal (twice daily)
    (crontab -l 2>/dev/null; echo "0 */12 * * * /usr/local/bin/renew-ssl.sh") | crontab -
    
    log "Automatic renewal configured (runs twice daily)"
}

# Verify SSL setup
verify_ssl() {
    log "Verifying SSL setup..."
    
    # Check certificate validity
    if openssl x509 -in "$CERT_PATH/cert.pem" -text -noout | grep -q "$DOMAIN_NAME"; then
        log "Certificate is valid for $DOMAIN_NAME"
    else
        error "Certificate validation failed"
        return 1
    fi
    
    # Check HTTPS response
    if curl -sSf "https://$DOMAIN_NAME/health" > /dev/null; then
        log "HTTPS endpoint is responding correctly"
    else
        warning "HTTPS endpoint check failed - this may be normal if services aren't running yet"
    fi
    
    # Check SSL rating (if SSL Labs API is available)
    info "You can check your SSL configuration at: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN_NAME"
}

# Main function
main() {
    log "Starting SSL setup for DisplayDeck..."
    log "Domain: $DOMAIN_NAME"
    log "Email: $EMAIL"
    
    check_root
    install_certbot
    backup_certificates
    create_initial_nginx_config
    
    # Wait a moment for nginx to reload
    sleep 5
    
    generate_certificate
    create_ssl_nginx_config
    setup_renewal
    verify_ssl
    
    log "SSL setup completed successfully!"
    log "Your site is now available at: https://$DOMAIN_NAME"
    info "Certificate will auto-renew. Check renewal status with: certbot renew --dry-run"
}

# Handle script arguments
case "${1:-}" in
    "renew")
        log "Renewing SSL certificates..."
        certbot renew
        systemctl reload nginx || service nginx reload
        log "Certificate renewal completed"
        ;;
    "test")
        log "Testing certificate renewal..."
        certbot renew --dry-run
        ;;
    "status")
        log "Certificate status:"
        certbot certificates
        ;;
    "backup")
        backup_certificates
        log "Certificate backup completed"
        ;;
    *)
        main
        ;;
esac