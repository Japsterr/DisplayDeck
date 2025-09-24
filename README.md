# DisplayDeck - Digital Menu Management System

A comprehensive multi-platform digital menu management solution for restaurants, featuring real-time synchronization, QR code pairing, and enterprise-grade scalability.

## 🚀 Quick Start (No Traefik Required)

### Option 1: Simple Deployment
```bash
git clone https://github.com/Japsterr/DisplayDeck.git
cd DisplayDeck
cp .env.example .env
# Edit .env with your settings
docker-compose -f docker-compose.simple.yml up -d
```

### Option 2: Standard Production Deployment
```bash
git clone https://github.com/Japsterr/DisplayDeck.git
cd DisplayDeck
cp .env.example .env
# Edit .env with your domain and credentials
docker-compose -f deployment/docker/docker-compose.prod.yml up -d
```

### Access Your Application
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000/api/v1  
- **Admin Panel**: http://localhost:8000/admin
- **API Docs**: http://localhost:8000/docs

## ✨ Features

### 🍽️ Restaurant Management
- **Real-time Menu Updates** - Instant synchronization across all displays
- **Multi-location Support** - Manage multiple restaurant locations from one dashboard
- **Role-based Permissions** - Staff, manager, and owner access levels
- **QR Code Display Pairing** - Connect new displays in seconds

### 📱 Mobile App (React Native)
- **Biometric Authentication** - Fingerprint and face recognition
- **Offline Support** - Work without internet, sync when connected
- **Push Notifications** - Instant alerts for display issues
- **QR Scanner** - Pair displays by scanning QR codes

### 🖥️ Display Client (Android TV)
- **TV-Optimized Interface** - Beautiful menu displays for customer viewing
- **Offline Caching** - Continue showing menus during network outages
- **Auto-updates** - Automatic menu synchronization in background
- **Health Monitoring** - Real-time status reporting

### 🛡️ Security & Performance
- **JWT Authentication** - Secure API access with refresh tokens
- **Multi-tenant Architecture** - Complete business isolation
- **Performance Optimized** - Database indexing, Redis caching, CDN integration
- **Enterprise Ready** - Docker deployment, monitoring, backups

## 📋 System Requirements

### Minimum Requirements
- **CPU**: 2 cores
- **RAM**: 4GB
- **Storage**: 20GB SSD
- **Network**: Broadband internet connection

### Recommended Production
- **CPU**: 4+ cores  
- **RAM**: 8GB+
- **Storage**: 50GB+ SSD
- **Network**: Dedicated server or VPS

## 🏗️ Architecture

```
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│   Mobile    │    │   Web App    │    │ Android TV  │
│    App      │    │ (Dashboard)  │    │  Displays   │
└─────────────┘    └──────────────┘    └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌──────────────┐
                    │   API Gateway │
                    │   (Nginx)     │
                    └──────────────┘
                           │
          ┌────────────────┼────────────────┐
          │                                 │
   ┌──────────────┐              ┌──────────────┐
   │   Backend    │              │  Real-time   │
   │  (Django)    │◄────────────►│  WebSocket   │
   └──────────────┘              └──────────────┘
          │                               │
          └───────────────┬───────────────┘
                          │
          ┌───────────────┼───────────────┐
          │               │               │
   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
   │ PostgreSQL  │ │    Redis    │ │   Media     │
   │ Database    │ │   Cache     │ │   Storage   │
   └─────────────┘ └─────────────┘ └─────────────┘
```

## 📦 Installation Options

### 🐳 Docker Deployment (Recommended)

1. **Simple Setup** (Direct access, no reverse proxy):
   ```bash
   docker-compose -f docker-compose.simple.yml up -d
   ```

2. **Production Setup** (With Nginx reverse proxy):
   ```bash
   docker-compose -f deployment/docker/docker-compose.prod.yml up -d
   ```

3. **Development Setup**:
   ```bash
   docker-compose -f docker-compose.dev.yml up -d
   ```

### ⚙️ Manual Installation

See [DEVELOPMENT.md](DEVELOPMENT.md) for detailed manual setup instructions.

## 🔧 Configuration

### Environment Variables (.env)
```bash
# Database
POSTGRES_DB=displaydeck
POSTGRES_USER=displaydeck  
POSTGRES_PASSWORD=your_secure_password

# Django
SECRET_KEY=your-very-long-secret-key
DEBUG=False
ALLOWED_HOSTS=localhost,your-domain.com

# Frontend URLs  
VITE_API_BASE_URL=http://localhost:8000
VITE_WS_URL=ws://localhost:8000

# Optional: Domain & SSL
DOMAIN_NAME=your-domain.com
LETSENCRYPT_EMAIL=admin@your-domain.com
```

### Default Credentials
- **Admin Username**: admin
- **Admin Password**: admin
- ⚠️ **Change immediately after first login!**

## 📚 Documentation

- **[Simple Deployment Guide](docs/simple-deployment.md)** - No-Traefik setup
- **[Full Deployment Guide](docs/deployment.md)** - Complete production setup
- **[User Guide](docs/user-guide.md)** - Restaurant staff manual
- **[API Documentation](http://localhost:8000/docs)** - Interactive API docs
- **[Development Guide](DEVELOPMENT.md)** - Developer setup instructions

## 🧪 Testing

```bash
# Backend tests
cd backend
python manage.py test

# Frontend tests  
cd frontend
npm run test

# Mobile tests
cd mobile
npm run test

# Full test suite
make test
```

## 🔍 Monitoring & Health Checks

### Built-in Health Checks
- **Backend**: http://localhost:8000/health/
- **Frontend**: http://localhost:3000/health  
- **Database**: Automatic PostgreSQL health monitoring
- **Cache**: Redis connectivity monitoring

### Optional Monitoring Stack
```bash
# Enable monitoring (Prometheus + Grafana)
docker-compose --profile monitoring up -d

# Access monitoring
# Prometheus: http://localhost:9090
# Grafana: http://localhost:3001 (admin/admin)
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [docs/](docs/)
- **Issues**: [GitHub Issues](https://github.com/Japsterr/DisplayDeck/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Japsterr/DisplayDeck/discussions)

## 🎯 Use Cases

### Perfect for:
- **Quick Service Restaurants (QSR)** - Fast menu updates for busy environments
- **Multi-location Chains** - Centralized menu management across locations
- **Cafes & Coffee Shops** - Simple menu displays with real-time availability
- **Food Trucks** - Mobile-friendly management with offline support
- **Ghost Kitchens** - Manage multiple brands from one system

### Key Benefits:
- ⚡ **Instant Updates** - Change prices and availability in real-time
- 📱 **Mobile-First** - Manage menus from anywhere with mobile app
- 🔒 **Secure** - Enterprise-grade authentication and permissions
- 💰 **Cost-Effective** - Eliminate printing costs and reduce waste
- 🌍 **Scalable** - From single location to enterprise chains

---

**Ready to revolutionize your restaurant's digital menu management?** 

Get started today: `git clone https://github.com/Japsterr/DisplayDeck.git`