# DisplayDeck Roadmap

Suggested features and improvements to make DisplayDeck a powerful enterprise-grade digital display platform.

---

## High Priority / Near Term

### 1. Scheduling System
- **Time-based content scheduling**: Allow content to display at specific times (breakfast menu 6-11am, lunch 11am-3pm, etc.)
- **Day-of-week scheduling**: Different content for weekdays vs weekends
- **Date-based scheduling**: Promotional content for specific dates (holidays, sales events)
- **Playlist priority**: When multiple schedules overlap, define which takes precedence

### 2. Multi-Zone Layouts
- **Split-screen displays**: Show menu on left, promotions on right
- **Ticker zones**: Scrolling text at bottom for announcements
- **Time/date widget zones**: Always-visible clock, weather
- **Custom zone templates**: Define reusable layouts

### 3. Remote Display Management
- **Screenshot capture**: Remotely capture what's currently on screen
- **Remote restart**: Reboot display app without physical access
- **Brightness control**: Adjust display brightness remotely
- **Orientation lock**: Force landscape/portrait from dashboard

### 4. Analytics & Reporting
- **Playback analytics**: Track which content played, when, for how long
- **Display uptime reports**: See online/offline history per display
- **Content performance**: Which items are shown most, engagement metrics
- **Export reports**: CSV/PDF exports for stakeholders

---

## Medium Priority / Mid Term

### 5. Content Transitions & Effects
- **Slide transitions**: Fade, slide, zoom between campaign items
- **Animation presets**: Ken Burns effect for images, smooth text scrolls
- **Custom timing**: Control transition speed and delays

### 6. Interactive Features
- **Touch screen support**: Allow customers to browse menus on kiosks
- **QR code integration**: Dynamic QR codes linking to ordering systems
- **Input fields**: Feedback collection, simple surveys

### 7. External Data Integration
- **Weather widgets**: Live weather display
- **Social media feeds**: Display Instagram, Twitter, Facebook posts
- **RSS/News feeds**: Show live news or company updates
- **POS integration**: Pull live pricing/availability from POS systems
- **Google Sheets sync**: Update content from spreadsheets

### 8. Content Templates Library
- **Pre-built templates**: Industry-specific designs (restaurant, retail, corporate, healthcare)
- **Template marketplace**: User-contributed templates
- **Canva/Figma import**: Import designs from popular tools

### 9. User & Team Management
- **Role-based access**: Admin, Editor, Viewer roles per organization
- **Multi-location support**: Manage displays across multiple venues
- **Approval workflows**: Content review before publish
- **Audit logs**: Track who changed what and when

---

## Lower Priority / Long Term

### 10. Offline Mode Improvements
- **Full offline caching**: Pre-download all content for network outages
- **Fallback content**: Default content when network unavailable
- **Sync queue**: Queue changes when offline, sync when reconnected

### 11. Hardware Expansion
- **Raspberry Pi support**: Lightweight player for Raspberry Pi
- **Windows/Linux desktop app**: Player apps for PC-based displays
- **Samsung Tizen / LG webOS apps**: Native smart TV apps
- **BrightSign integration**: Support professional signage players

### 12. White Label / Reseller
- **Custom branding**: Remove DisplayDeck branding, add customer's logo
- **Custom domains**: Use customer's domain for dashboard
- **Reseller portal**: Manage multiple customers as a reseller

### 13. AI Features
- **Auto-layout**: AI suggests optimal content layout
- **Image optimization**: Automatic cropping/resizing for displays
- **Content suggestions**: AI recommends content based on performance
- **Translation**: Auto-translate menu items to multiple languages

### 14. Enterprise Features
- **SSO/SAML**: Single sign-on with corporate identity providers
- **Active Directory sync**: Import users from AD
- **API rate limiting & usage tracking**: Enterprise API management
- **SLA guarantees**: Uptime commitments for enterprise plans

---

## Technical Debt & Infrastructure

### Performance
- [ ] Image optimization pipeline (WebP, responsive sizes)
- [ ] CDN caching for static assets
- [ ] Database query optimization for large organizations
- [ ] Load testing and performance benchmarks

### Reliability
- [ ] Automated backup system for database
- [ ] Disaster recovery documentation
- [ ] Health monitoring and alerting (Prometheus/Grafana)
- [ ] Automated failover for critical services

### Developer Experience
- [ ] Comprehensive API documentation with examples
- [ ] SDK for common languages (JavaScript, Python, C#)
- [ ] Webhook system for real-time integrations
- [ ] Public API rate limits and quotas

### Security
- [ ] Security audit and penetration testing
- [ ] Two-factor authentication (2FA)
- [ ] API key scoping and rotation
- [ ] GDPR compliance tools

---

## Completed Features ✓

- ✅ Multi-tenant organization structure
- ✅ Display provisioning with pairing codes
- ✅ Campaign management with media items
- ✅ Menu builder with multiple templates
- ✅ InfoBoard display type
- ✅ Android TV player app
- ✅ Real-time heartbeat monitoring
- ✅ Media library with S3-compatible storage
- ✅ JWT authentication
- ✅ OpenAPI documentation
- ✅ Docker-based deployment
- ✅ Cloudflare Tunnel support

---

*Last updated: January 4, 2026*
