# Research Findings: DisplayDeck Technology Stack

## Django REST Framework Authentication

**Decision**: JWT with refresh tokens using `djangorestframework-simplejwt`
**Rationale**: 
- Stateless authentication suitable for multi-platform clients
- Built-in token refresh mechanism for security
- Native Django integration with user models
- Support for role-based permissions via Django groups

**Alternatives Considered**:
- Session-based auth: Rejected due to mobile app requirements
- OAuth 2.0 only: Rejected as overkill for primary use case, added as integration option

**Implementation Notes**:
- Access token: 15 minutes expiry
- Refresh token: 7 days expiry  
- Custom user model with business association
- Django Guardian for object-level permissions

## Real-time Updates Architecture

**Decision**: WebSockets using Django Channels with Redis channel layer
**Rationale**:
- Bidirectional communication for display health monitoring
- Django Channels provides native Django integration
- Redis channel layer scales horizontally
- WebSocket fallback to Server-Sent Events for older browsers

**Alternatives Considered**:
- Server-Sent Events only: Rejected due to lack of bidirectional communication
- Polling: Rejected due to inefficiency and battery impact on displays

**Implementation Notes**:
- Separate WebSocket consumers for displays vs. admin users
- Message queuing for guaranteed delivery to offline displays
- Heartbeat mechanism every 60 seconds

## React Native Cross-Platform Development

**Decision**: React Native 0.72+ with Expo managed workflow
**Rationale**:
- Single codebase for iOS and Android
- Expo provides camera, biometric auth, push notification APIs
- Over-the-air updates for rapid deployment
- Strong TypeScript support

**Alternatives Considered**:
- Native development: Rejected due to development time and maintenance overhead
- Flutter: Rejected due to team expertise and ecosystem

**Platform-Specific Considerations**:
- iOS: Biometric authentication via TouchID/FaceID
- Android: Biometric authentication via BiometricPrompt API
- Push notifications: Firebase Cloud Messaging for both platforms
- QR scanning: Expo Camera with barcode scanning

## Android TV Development

**Decision**: Kotlin with Jetpack Compose for TV and modern Android architecture
**Rationale**:
- Compose for TV provides optimized UI components for large screens
- MVVM architecture with Repository pattern for clean separation
- Room database for local SQLite caching
- WorkManager for background synchronization

**Alternatives Considered**:
- Java: Rejected in favor of modern Kotlin development
- WebView-based: Rejected due to performance and offline requirements
- Legacy View system: Rejected in favor of declarative Compose UI

**Implementation Notes**:
- Minimum API 26 (Android 8.0) for widespread TV compatibility
- Offline-first architecture with background sync
- Exponential backoff retry logic for network failures
- TV-optimized navigation and focus handling

## Image Optimization Pipeline

**Decision**: Django with Pillow + CloudFlare Images or AWS CloudFront
**Rationale**:
- Pillow for server-side image processing during upload
- Multiple format generation (WebP, JPEG) for browser compatibility
- CDN for fast global delivery to displays
- Automatic resizing for different display resolutions

**Alternatives Considered**:
- Client-side processing: Rejected due to consistency and quality concerns
- Third-party services (Cloudinary): Considered for enterprise features

**Implementation Pipeline**:
1. Upload validation (size, format, content scanning)
2. Virus/content moderation scanning
3. Automatic resizing (thumbnail, display, hi-res)
4. Format conversion (WebP with JPEG fallback)
5. CDN upload with cache invalidation

## Container Orchestration for Portainer

**Decision**: Docker Swarm with Docker Stack files
**Rationale**:
- Native Docker orchestration, simpler than Kubernetes
- Portainer has excellent Docker Swarm integration
- One-click deployment via stack files
- Built-in load balancing and health checks

**Alternatives Considered**:
- Kubernetes: Rejected due to complexity for target deployment environment
- Docker Compose: Rejected due to lack of orchestration features

**Deployment Architecture**:
- Multi-stage Docker builds for optimization
- Separate services: API, Frontend, Database, Redis, Nginx
- Named volumes for data persistence
- Internal network for service communication
- Traefik for SSL termination and routing

## PostgreSQL Multi-tenancy

**Decision**: Shared database with Row-Level Security (RLS)
**Rationale**:
- Single database reduces operational complexity
- RLS provides automatic data isolation
- Better resource utilization than separate databases
- Django middleware for automatic tenant context

**Alternatives Considered**:
- Separate databases per tenant: Rejected due to management overhead
- Schema-based isolation: Rejected due to migration complexity

**Implementation Strategy**:
- `business_id` column on all tenant-specific tables
- RLS policies for automatic filtering
- Django middleware to set tenant context
- Connection pooling with PgBouncer

## Offline-First Mobile Strategy

**Decision**: Redux Persist with custom sync middleware
**Rationale**:
- Redux provides predictable state management
- Redux Persist handles offline storage automatically
- Custom middleware for conflict resolution
- Background sync when connectivity restored

**Alternatives Considered**:
- Realm: Rejected due to complexity and sync server requirements  
- SQLite with custom ORM: Rejected due to development time

**Sync Strategy**:
- Optimistic updates with conflict resolution
- Last-write-wins for simple updates (prices)
- Operational transforms for complex changes (menu structure)
- Manual conflict resolution UI for significant conflicts

## Performance and Monitoring

**Decision**: Django Debug Toolbar + Sentry + Prometheus/Grafana
**Rationale**:
- Django Debug Toolbar for development profiling
- Sentry for error tracking and performance monitoring
- Prometheus for metrics collection, Grafana for visualization
- Custom metrics for business KPIs (display uptime, sync success)

**Key Metrics to Track**:
- API response times (p50, p95, p99)
- Display sync success rate and timing
- User activity patterns and feature usage
- Database query performance and slow queries
- Media delivery performance via CDN

## Security Considerations

**Decision**: Comprehensive security-first approach
- HTTPS/TLS everywhere with Let's Encrypt certificates
- JWT token signing with RS256 asymmetric keys
- API rate limiting with Redis-based sliding windows
- Input validation and sanitization at all layers
- SQL injection prevention via Django ORM
- XSS prevention via Content Security Policy

**Compliance Requirements**:
- GDPR compliance for EU users (data retention, deletion)
- PCI DSS considerations for payment processing (future)
- SOC 2 Type II preparation for enterprise customers

---

## Research Summary

All critical technology decisions have been made with clear rationales and implementation guidance. The architecture supports the constitutional requirements for modern, secure, scalable, and maintainable software while meeting all functional requirements from the specification.

**Next Phase**: Design detailed data models, API contracts, and integration test scenarios based on these research findings.