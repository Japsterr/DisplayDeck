# API Specification Outline for DisplayDeck

## Core API Endpoints

### Authentication
- `POST /api/auth/login` - JWT authentication with business context
- `POST /api/auth/refresh` - Token refresh mechanism
- `POST /api/auth/logout` - Token invalidation

### Business & User Management  
- `POST /api/businesses` - Create new business account
- `GET /api/businesses/{id}/users` - List business users
- `POST /api/businesses/{id}/users/invite` - Invite new user
- `PUT /api/users/{id}/role` - Update user permissions

### Menu Management
- `GET /api/businesses/{id}/menus` - List all menus
- `POST /api/businesses/{id}/menus` - Create new menu
- `PUT /api/menus/{id}` - Update entire menu
- `PATCH /api/menus/{id}/items/{item_id}/price` - Update single item price
- `DELETE /api/menus/{id}/categories/{category_id}` - Remove category

### Display Management
- `POST /api/displays/pair` - Link display via QR code
- `GET /api/businesses/{id}/displays` - List linked displays  
- `PUT /api/displays/{id}/menu` - Assign menu to display
- `GET /api/displays/{id}/status` - Display health check

### Real-time Updates
- WebSocket endpoint for live menu updates
- Server-Sent Events for display status monitoring

## Data Models Structure

### Business Account
```
{
  "id": "uuid",
  "name": "Restaurant Name", 
  "settings": {...},
  "created_at": "timestamp"
}
```

### Menu Item
```
{
  "id": "uuid",
  "name": "Burger",
  "price": 12.99,
  "description": "...",
  "image_url": "...",
  "category_id": "uuid",
  "available": true
}
```

### Display Device  
```
{
  "id": "uuid",
  "business_id": "uuid",
  "name": "Main Counter Display",
  "orientation": "landscape",
  "status": "online",
  "last_sync": "timestamp"
}
```

This API specification provides the foundation for the `/plan` phase where specific Django models, serializers, and endpoints will be designed.