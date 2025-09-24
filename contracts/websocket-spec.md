# WebSocket API Specification

## Connection Endpoints

### Admin WebSocket
- **URL**: `wss://api.displaydeck.com/ws/admin/`
- **Authentication**: JWT token via query parameter or Authorization header
- **Purpose**: Real-time updates for web admin panel and mobile app

### Display WebSocket  
- **URL**: `wss://api.displaydeck.com/ws/display/{display_id}/`
- **Authentication**: Display device token
- **Purpose**: Menu updates, health monitoring, and coordination

## Message Format

All WebSocket messages follow this JSON structure:
```json
{
  "type": "message_type",
  "payload": {},
  "timestamp": "2025-09-24T10:30:00Z",
  "message_id": "uuid-v4"
}
```

## Admin WebSocket Messages

### Incoming Messages (Admin → Server)

#### Subscribe to Business Updates
```json
{
  "type": "subscribe_business",
  "payload": {
    "business_id": "uuid"
  }
}
```

#### Subscribe to Display Updates
```json
{
  "type": "subscribe_display",
  "payload": {
    "display_id": "uuid"
  }
}
```

#### Menu Update Broadcast
```json
{
  "type": "menu_updated",
  "payload": {
    "menu_id": "uuid",
    "version": 2,
    "changes": ["prices", "items", "layout"]
  }
}
```

### Outgoing Messages (Server → Admin)

#### Display Status Change
```json
{
  "type": "display_status_changed",
  "payload": {
    "display_id": "uuid",
    "old_status": "online",
    "new_status": "offline", 
    "last_heartbeat": "2025-09-24T10:29:45Z"
  }
}
```

#### Menu Sync Status
```json
{
  "type": "menu_sync_status",
  "payload": {
    "display_id": "uuid",
    "menu_id": "uuid",
    "status": "success|error|in_progress",
    "sync_duration_ms": 1250,
    "error_message": null
  }
}
```

#### User Activity Notification
```json
{
  "type": "user_activity",
  "payload": {
    "user_id": "uuid",
    "action": "menu_updated|display_paired|item_price_changed",
    "entity_id": "uuid",
    "details": {}
  }
}
```

## Display WebSocket Messages

### Incoming Messages (Display → Server)

#### Heartbeat
```json
{
  "type": "heartbeat",
  "payload": {
    "display_id": "uuid",
    "status": "online",
    "performance_stats": {
      "cpu_usage": 15.2,
      "memory_usage": 45.8,
      "storage_free_gb": 8.5,
      "network_strength": 85
    }
  }
}
```

#### Pairing Request
```json
{
  "type": "pairing_request", 
  "payload": {
    "device_id": "android-device-unique-id",
    "device_info": {
      "android_version": "11",
      "screen_resolution": "1920x1080",
      "orientation": "landscape"
    }
  }
}
```

#### Sync Acknowledgment
```json
{
  "type": "sync_ack",
  "payload": {
    "menu_id": "uuid",
    "version": 2,
    "status": "success|error",
    "error_details": null,
    "items_cached": 25
  }
}
```

### Outgoing Messages (Server → Display)

#### Menu Update
```json
{
  "type": "menu_update",
  "payload": {
    "menu_id": "uuid",
    "version": 2,
    "update_type": "full|incremental",
    "menu_data": {
      "name": "Main Menu",
      "layout_template": "grid",
      "categories": [...],
      "items": [...],
      "styling": {...}
    },
    "media_assets": [
      {
        "asset_id": "uuid",
        "url": "https://cdn.displaydeck.com/...",
        "checksum": "sha256-hash"
      }
    ]
  }
}
```

#### Pairing Response
```json
{
  "type": "pairing_response",
  "payload": {
    "status": "success|error",
    "display_id": "uuid", 
    "business_id": "uuid",
    "pairing_code": "ABC123DEF",
    "expires_at": "2025-09-24T10:40:00Z"
  }
}
```

#### Display Command
```json
{
  "type": "display_command",
  "payload": {
    "command": "restart|update_firmware|clear_cache",
    "parameters": {}
  }
}
```

#### Group Coordination
```json
{
  "type": "group_sync",
  "payload": {
    "group_id": "uuid",
    "sync_token": "unique-sync-id",
    "position": "left|center|right",
    "wait_for_confirmation": true,
    "menu_data": {...}
  }
}
```

## Connection States

### Admin Connection Lifecycle
1. **Connect**: WebSocket established with JWT authentication
2. **Subscribe**: Client subscribes to relevant business/display channels
3. **Active**: Bidirectional message exchange
4. **Reconnect**: Automatic reconnection with exponential backoff
5. **Disconnect**: Clean connection closure

### Display Connection Lifecycle  
1. **Connect**: WebSocket established with device authentication
2. **Authenticate**: Server validates display credentials
3. **Heartbeat**: Regular status updates every 60 seconds
4. **Sync**: Menu updates and acknowledgments
5. **Disconnect**: Connection lost, automatic reconnection

## Error Handling

### WebSocket Error Messages
```json
{
  "type": "error",
  "payload": {
    "code": "AUTHENTICATION_FAILED|SUBSCRIPTION_FAILED|RATE_LIMITED",
    "message": "Human readable error message",
    "details": {}
  }
}
```

### Connection Errors
- **4001 Unauthorized**: Invalid or expired token
- **4002 Forbidden**: Insufficient permissions for subscription
- **4003 Rate Limited**: Too many messages sent
- **4004 Invalid Message**: Malformed message format

## Rate Limiting

### Admin Connections
- **Message Rate**: 100 messages per minute
- **Subscription Limit**: 50 concurrent subscriptions
- **Connection Limit**: 5 concurrent connections per user

### Display Connections  
- **Heartbeat Rate**: 1 message per minute (required)
- **Sync Rate**: 10 sync acknowledgments per minute
- **Connection Limit**: 1 connection per display device

## Security Considerations

### Authentication
- Admin connections require valid JWT tokens
- Display connections use device-specific authentication tokens
- Tokens validated on every message for admin connections

### Message Validation
- All incoming messages validated against JSON schemas
- Rate limiting applied per connection
- Message size limited to 1MB for menu updates

### Channel Isolation
- Business-level message isolation via subscriptions
- Display messages only routed to associated business admins
- No cross-tenant message leakage

## Implementation Notes

### Backend (Django Channels)
```python
# WebSocket Consumer example structure
class AdminConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        # JWT authentication
        # Channel group management
        
    async def receive(self, text_data):
        # Message routing and validation
        
    async def menu_updated(self, event):
        # Broadcast menu updates to subscribed clients
```

### Frontend (JavaScript)
```javascript
// WebSocket client connection
const ws = new WebSocket('wss://api.displaydeck.com/ws/admin/');
ws.onopen = () => {
  // Subscribe to business updates
  ws.send(JSON.stringify({
    type: 'subscribe_business',
    payload: { business_id: 'uuid' }
  }));
};
```

### Android Display Client (Kotlin)
```kotlin
// WebSocket connection with OkHttp
class DisplayWebSocketClient {
    fun connect(displayId: String) {
        val request = Request.Builder()
            .url("wss://api.displaydeck.com/ws/display/$displayId/")
            .build()
        // Connection management and message handling
    }
}
```

This WebSocket specification enables real-time communication for menu updates, display monitoring, and multi-screen coordination while maintaining security and performance requirements.