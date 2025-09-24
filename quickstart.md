# DisplayDeck Quickstart Deployment Guide

Welcome to DisplayDeck! This guide will help you deploy the complete digital menu management system across all platforms.

## 🚀 Quick Start

### Prerequisites

- **Python 3.8+** (for Django backend)
- **Node.js 16+** (for React frontend)
- **Git** (for version control)
- **Docker** (optional, for containerized deployment)

### 1. Clone and Setup

```bash
git clone https://github.com/your-repo/DisplayDeck.git
cd DisplayDeck

# Run system validation
python validate_system.py

# Clone and setup backend
cd backend
python -m venv venv
source venv/bin/activate  # or `venv\Scripts\activate` on Windows
pip install -r requirements.txt

# Setup database
createdb displaydeck_dev
python manage.py migrate
python manage.py createsuperuser

# Setup frontend
cd ../frontend  
npm install
cp .env.example .env.local

# Setup mobile app
cd ../mobile
npm install
npx expo install

# Setup Android display client
cd ../android-display
./gradlew build
```

## Core User Journeys

### 1. Business Account Creation and User Management

**Test Scenario**: Restaurant owner creates account and invites staff

```bash
# 1. Create business account via API
curl -X POST http://localhost:8000/api/v1/businesses/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "name": "Demo Restaurant",
    "subscription_tier": "professional",
    "timezone": "America/New_York"
  }'

# 2. Invite manager
curl -X POST http://localhost:8000/api/v1/businesses/{business_id}/users/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "email": "manager@demorestaurant.com",
    "role": "manager"
  }'
```

**Expected Results**:
- Business account created with unique ID and slug
- Owner has full access permissions
- Manager receives email invitation
- Business appears in owner's business list

**Frontend Test Path**: 
1. Navigate to `/register`
2. Complete business registration form
3. Verify email and login
4. Access admin dashboard at `/dashboard`
5. Navigate to Team Management
6. Send user invitation
7. Check invitation status

### 2. Menu Creation and Management

**Test Scenario**: Create a complete restaurant menu with categories and items

```bash
# 1. Create menu
MENU_ID=$(curl -X POST http://localhost:8000/api/v1/businesses/{business_id}/menus/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "name": "Main Menu",
    "description": "Our signature dishes",
    "layout_template": "grid"
  }' | jq -r '.id')

# 2. Create category  
CATEGORY_ID=$(curl -X POST http://localhost:8000/api/v1/menus/$MENU_ID/categories/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "name": "Appetizers",
    "description": "Start your meal right",
    "sort_order": 1
  }' | jq -r '.id')

# 3. Add menu item
curl -X POST http://localhost:8000/api/v1/categories/$CATEGORY_ID/items/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "name": "Buffalo Wings",
    "description": "Crispy wings with buffalo sauce",
    "price": "12.99",
    "allergens": ["gluten"],
    "dietary_flags": []
  }'
```

**Expected Results**:
- Menu created with version 1
- Category appears in menu structure
- Menu item displays with correct pricing
- Menu can be assigned to displays

**Frontend Test Path**:
1. Navigate to `/dashboard/menus`
2. Click "Create New Menu"
3. Fill menu details and save
4. Add categories using drag-and-drop builder
5. Add items to categories
6. Preview menu in different layouts
7. Publish menu

### 3. Display Pairing and Management

**Test Scenario**: Pair Android TV display with business account via QR code

**Mobile App Test Path**:
1. Open mobile app and login
2. Navigate to "Displays" section  
3. Tap "Add New Display"
4. Scan QR code from Android TV

**Android TV Display Path**:
1. Start DisplayDeck app on Android TV
2. App generates pairing QR code
3. Display QR code on screen for 10 minutes
4. Wait for mobile app to scan

**API Verification**:
```bash
# Check pairing status
curl -X GET http://localhost:8000/api/v1/displays/{display_id}/status \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# Assign menu to display
curl -X PUT http://localhost:8000/api/v1/displays/{display_id}/menu \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "menu_id": "{menu_id}"
  }'
```

**Expected Results**:
- Display appears in business display list
- Display status shows as "online"
- Menu assignment triggers sync to display
- Display shows menu content within 60 seconds

### 4. Real-Time Menu Updates

**Test Scenario**: Update menu item price and verify real-time sync to displays

```bash
# Update item price via API
curl -X PATCH http://localhost:8000/api/v1/menus/{menu_id}/items/{item_id}/price \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "price": "14.99"
  }'

# Verify WebSocket message sent
# (Monitor WebSocket connection for menu_update message)
```

**WebSocket Test**:
```javascript
// Connect to admin WebSocket
const ws = new WebSocket('ws://localhost:8000/ws/admin/');
ws.onopen = () => {
  ws.send(JSON.stringify({
    type: 'subscribe_business',
    payload: { business_id: 'business-uuid' }
  }));
};

ws.onmessage = (event) => {
  const message = JSON.parse(event.data);
  console.log('Received:', message);
  // Expected: menu_sync_status message
};
```

**Expected Results**:
- Price update reflected immediately in admin interface
- WebSocket message sent to all connected displays  
- Displays update within 30 seconds
- Mobile app shows updated price (if viewing menu)

### 5. Multi-Screen Coordination

**Test Scenario**: Setup 3-display menu group with different orientations

```bash
# Create display group
GROUP_ID=$(curl -X POST http://localhost:8000/api/v1/businesses/{business_id}/display-groups/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "name": "Main Counter Displays",
    "sync_strategy": "simultaneous"
  }' | jq -r '.id')

# Add displays to group  
curl -X POST http://localhost:8000/api/v1/display-groups/$GROUP_ID/members/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "display_device": "{display_1_id}",
    "position": "left",
    "is_primary": true
  }'

# Assign menu to group
curl -X PUT http://localhost:8000/api/v1/display-groups/$GROUP_ID/menu \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "menu_id": "{menu_id}"
  }'
```

**Expected Results**:
- All displays in group receive synchronized updates
- Primary display coordinates timing
- Mixed orientations display content appropriately
- Group status shows all displays online

## Mobile App Testing

### QR Code Scanning Flow
```bash
# Mobile simulator testing
npx expo start --ios  # or --android
# Test QR scanning with device camera
```

### Offline Mode Testing
```bash
# Disconnect network during menu editing
# Verify changes queued locally
# Reconnect and verify sync
```

### Push Notifications
```bash
# Configure Firebase/APNs credentials
# Test display offline notifications
# Test menu update confirmations
```

## Android Display Client Testing

### Local Development
```bash
cd android-display
./gradlew assembleDebug
adb install app/build/outputs/apk/debug/app-debug.apk

# Test on Android TV emulator
emulator -avd AndroidTV_API_30
```

### Offline Caching Test
```bash
# Verify SQLite database creation
adb shell
sqlite3 /data/data/com.displaydeck.client/databases/menu_cache.db
.tables
SELECT * FROM cached_menus;
```

## Performance Testing

### API Load Testing
```bash
# Install artillery for load testing
npm install -g artillery

# Run load test
artillery run api-load-test.yml
```

### WebSocket Stress Testing
```javascript
// Test multiple WebSocket connections
for (let i = 0; i < 100; i++) {
  const ws = new WebSocket('ws://localhost:8000/ws/admin/');
  // Monitor connection health
}
```

### Database Performance
```sql
-- Monitor query performance
EXPLAIN ANALYZE SELECT * FROM menus 
WHERE business_id = 'uuid' AND is_published = true;

-- Check index usage
SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read 
FROM pg_stat_user_indexes 
ORDER BY idx_scan DESC;
```

## Deployment Testing

### Docker Development Stack
```bash
# Start all services
docker-compose -f docker-compose.dev.yml up -d

# Check service health
docker-compose ps
curl http://localhost:8000/health/
curl http://localhost:3000/
```

### Portainer Stack Deployment
```bash
# Deploy to Portainer
docker stack deploy -c docker-stack.yml displaydeck

# Monitor deployment
docker service ls
docker service logs displaydeck_api
```

## Monitoring and Debugging

### Application Logs
```bash
# Backend logs
tail -f logs/django.log

# Frontend development
npm run dev  # Watch mode with hot reload

# Mobile app logs
npx expo logs --type ios  # or android
```

### Database Monitoring
```sql
-- Active queries
SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '1 minutes';

-- Connection count
SELECT COUNT(*) FROM pg_stat_activity;
```

### Redis Monitoring  
```bash
redis-cli monitor
redis-cli info memory
redis-cli client list
```

This quickstart guide provides comprehensive testing scenarios for all major features and integration points. Each scenario includes expected results and verification steps to ensure the system meets functional requirements.