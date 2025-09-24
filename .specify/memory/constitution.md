# DisplayDeck Digital Menu System Constitution

## Core Principles

### I. Modern Technology Stack (NON-NEGOTIABLE)
**No obsolete or unsupported packages**: All dependencies, frameworks, and libraries must be actively maintained with recent releases and security patches. Before adopting any package, verify:
- Active development (commits within 6 months)
- Recent stable releases
- No known critical security vulnerabilities
- Community support and documentation
- Migration path if package becomes obsolete

### II. Responsive Web Architecture
**Universal accessibility**: The website must provide optimal user experience across all devices:
- Mobile-first responsive design
- Progressive enhancement
- Accessible to users with disabilities (WCAG 2.1 AA compliance)
- Fast loading times (<3s initial load, <1s subsequent pages)
- Offline-capable where appropriate
- Cross-browser compatibility (modern browsers only)

### III. Secure Authentication & Authorization
**Security-first approach**: User dashboard and administrative functions require robust security:
- Strong authentication mechanisms (multi-factor where possible)
- Role-based access control (RBAC)
- Session management with proper expiration
- HTTPS/TLS encryption for all communications
- Input validation and sanitization
- Protection against OWASP Top 10 vulnerabilities
- Audit logging for administrative actions

### IV. Dynamic Content Management & Menu System
**Flexible menu architecture**: The system must support comprehensive menu customization and multi-screen display management:
- **Menu Structure**: Hierarchical categories/sections with optional category images
- **Menu Items**: Each item includes name, price, description, and optional image
- **Layout Engine**: Multiple display layouts per menu (grid, list, featured, etc.)
- **Multi-Screen Support**: Link 2-3 screens together for coordinated display
- **Orientation Flexibility**: Support both landscape and portrait screen orientations
- **Brand Customization**: Customer-specific colors, logos, fonts, and styling themes
- **Easy Updates**: Intuitive interface for non-technical staff to modify menus
- **Real-time Synchronization**: Changes propagate to displays within seconds
- **Version Control**: Track menu changes with rollback capabilities
- **Asset Management**: Centralized image/video storage with optimization
- **Multi-Location**: Location-specific menu variations and pricing

### V. Android Display Client Requirements
**Reliable display performance**: The Android APK for TV displays must be:
- Lightweight and optimized for TV hardware
- Auto-updating content with fallback mechanisms
- Offline-capable with cached content
- Support for various screen resolutions and orientations
- Remote management and monitoring capabilities
- Crash recovery and self-healing mechanisms
- Minimal resource consumption

### VI. Mobile Management App (Cross-Platform)
**Field management capabilities**: A mobile app for restaurant managers and staff to:
- **Device Pairing**: Link displays to accounts via QR code scanning
- **Remote Management**: Control display settings, layouts, and content remotely
- **Menu Editing**: Create and modify menu items on-the-go
- **Real-time Monitoring**: View display status, connection health, and performance
- **Push Notifications**: Alerts for display issues, update confirmations
- **Offline Capability**: Queue changes when offline, sync when connected
- **Multi-Location**: Manage multiple restaurant locations from one app
- **Role-based Access**: Different permission levels for managers vs. staff

## Technical Constraints

### Core Technology Stack (MANDATED)
- **Frontend Web**: React 18+ with ShadCN UI component library
- **Mobile App**: React Native or Flutter for cross-platform mobile management
- **Backend**: Django (Python 3.11+) REST API
- **Deployment**: Docker containerization with Portainer-ready stack files
- **Database**: PostgreSQL with proper indexing and query optimization
- **Orchestration**: Docker Compose / Docker Stack for Portainer deployment

### Backend Requirements (Django API)
- Django REST Framework for API development
- RESTful API design with proper versioning
- JWT-based authentication with refresh tokens
- Comprehensive error handling and logging
- Automated testing coverage (minimum 80%)
- Docker multi-stage builds for optimization
- Environment-based configuration management

### Frontend Requirements (React + ShadCN UI)
- React 18+ with TypeScript for type safety
- ShadCN UI for consistent, accessible components
- Tailwind CSS for styling (ShadCN dependency)
- Build tools with Vite or Next.js for optimization
- Performance monitoring and analytics
- SEO optimization for public pages

### Android TV Display Requirements
- Target recent Android API levels (API 26+ minimum)
- Kotlin with modern development practices and coroutines
- Jetpack Compose for native UI (alternative to web-based display)
- Efficient memory and battery usage optimization
- Network resilience with exponential backoff retry logic
- Offline operation with local SQLite caching
- Remote configuration via Django API
- Support for multiple screen orientations and resolutions
- WebView integration for web-based menu rendering (if needed)
- Auto-update mechanism for APK distribution

### Mobile Management App Requirements
- **Cross-Platform**: React Native or Flutter for iOS and Android
- **Native Features**: Camera access for QR code scanning, push notifications
- **Offline-First**: Local storage with background synchronization
- **Real-time Updates**: WebSocket or Server-Sent Events for live status
- **Secure Authentication**: Biometric login support, secure token storage
- **Performance**: Fast startup (<2s), responsive UI, minimal battery usage
- **App Store Compliance**: Meet iOS App Store and Google Play guidelines

## Menu System Architecture

### Data Model Requirements
**Core Menu Entities**:
- **Categories/Sections**: Hierarchical grouping with optional images and descriptions
- **Menu Items**: Name, price, description, optional image, dietary flags, availability status
- **Layouts**: Template definitions for different display arrangements (grid, list, carousel, featured)
- **Screen Configurations**: Multi-screen setups with orientation specifications
- **Brand Themes**: Customer-specific color palettes, logo placement, typography choices
- **Display Groups**: Linking multiple screens for coordinated content

### Customization Framework
**Business Flexibility**:
- **Visual Identity**: Logo upload, brand colors (primary, secondary, accent), font selection
- **Layout Options**: Grid layouts (2x2, 3x3, etc.), list views, featured item displays
- **Screen Management**: Support 1-3 linked screens with mixed orientations
- **Content Adaptation**: Automatic content sizing based on screen resolution and orientation
- **Theme Templates**: Pre-built themes with customization overlays
- **Preview System**: Real-time preview of changes before deployment

### Easy Update Mechanism
**User-Friendly Management**:
- **Drag-and-Drop Interface**: Visual menu builder with intuitive controls (web and mobile)
- **Bulk Operations**: Mass price updates, category reordering, item status changes
- **Template System**: Reusable menu templates and seasonal variations
- **Change Scheduling**: Schedule menu updates for specific times/dates
- **Approval Workflow**: Optional review process for menu changes
- **Instant Preview**: See changes on actual display devices before publishing
- **Mobile Quick Edits**: Fast price/availability updates via mobile app
- **QR Code Pairing**: Simple display registration and management
- **Field Management**: On-site troubleshooting and configuration via mobile

## Quality Standards

### Performance Benchmarks
- Website: Lighthouse score >90 for Performance, Accessibility, SEO
- API: Response times <200ms for 95th percentile
- Android App: Startup time <3 seconds, content refresh <10 seconds

### Testing Requirements
- Unit tests for all business logic
- Integration tests for API endpoints
- End-to-end tests for critical user flows
- Performance testing under load
- Security testing and vulnerability assessments
- Cross-platform compatibility testing

### Documentation Standards
- API documentation with examples
- User manuals for content management
- Technical documentation for deployment
- Code comments and inline documentation
- Architecture decision records (ADRs)

## Portainer Deployment Strategy

### One-Click Deployment Requirements
**Simplified Operations**: The entire system must be deployable via Portainer with minimal configuration:
- **Docker Stack Files**: Pre-configured YAML files for all services
- **Environment Templates**: Parameterized configuration for different environments
- **Volume Management**: Persistent storage for database, media, and configuration
- **Network Configuration**: Internal service communication and external access
- **Health Checks**: Built-in monitoring and auto-restart capabilities
- **Backup Integration**: Automated database and media backup solutions

### Portainer Stack Components
**Service Architecture**:
- **Web Frontend**: React app served via Nginx with SSL termination
- **Django API**: Backend service with worker processes and task queues
- **PostgreSQL**: Database with persistent volumes and backup scheduling
- **Redis**: Caching and session storage (optional WebSocket support)
- **Media Storage**: File server for images and assets with CDN capabilities
- **Reverse Proxy**: Traefik or Nginx for routing and SSL management

### Ubuntu Server Optimization
**Host System Requirements**:
- Ubuntu 20.04 LTS or newer with Docker and Docker Compose
- Minimum 4GB RAM, 2 CPU cores, 50GB storage (scalable)
- Automatic updates and security patches
- UFW firewall configuration templates
- SSL certificate management (Let's Encrypt integration)
- Log aggregation and rotation policies

## Operational Excellence

### Monitoring & Observability
- Application performance monitoring
- Error tracking and alerting
- Usage analytics and reporting
- Infrastructure monitoring
- Security incident detection

### Deployment & CI/CD
- **Docker-First**: All services containerized with Docker
- **Portainer Integration**: Docker Stack files for one-click deployment
- Multi-stage builds for optimization
- Docker Compose for local development
- Docker Swarm mode for production orchestration
- **One-Click Deploy**: Pre-configured stack templates for Portainer
- Automated testing in CI/CD pipeline
- Staged deployment (dev → staging → production)
- Blue-green deployment for zero-downtime updates
- Rollback capabilities with container versioning
- Database migration management in containers
- Dependency vulnerability scanning
- Environment-specific configuration via environment variables
- **Ubuntu Server Ready**: Optimized for Ubuntu host systems
- Volume management for persistent data and media assets

## Governance

### Decision Making
- All architectural decisions must be documented as ADRs
- Technology choices must be justified with research
- Security changes require peer review
- Performance regressions must be addressed before release

### Code Quality
- Code review required for all changes
- Automated linting and formatting
- Static analysis for security issues
- Regular dependency updates and security patches

### Compliance
- This constitution supersedes all other development practices
- Deviations must be documented and approved
- Regular reviews to ensure continued relevance
- Amendment process requires consensus and migration plan

**Version**: 1.0 | **Ratified**: September 24, 2025 | **Last Amended**: September 24, 2025