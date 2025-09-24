# Data Model Design: DisplayDeck

## Core Entities and Relationships

### Business Account Management

#### BusinessAccount
```
Fields:
- id: UUID (primary key)
- name: CharField(max_length=255) - Business name
- slug: SlugField(unique=True) - URL-friendly identifier
- subscription_tier: CharField(choices=['basic', 'professional', 'enterprise'])
- subscription_status: CharField(choices=['active', 'suspended', 'cancelled'])
- max_displays: IntegerField - Based on subscription tier
- max_users: IntegerField - Based on subscription tier
- max_menus: IntegerField - Based on subscription tier
- settings: JSONField - Custom business configuration
- logo_url: URLField(blank=True) - Business logo
- primary_color: CharField(max_length=7) - Hex color code
- secondary_color: CharField(max_length=7) - Hex color code
- timezone: CharField(max_length=50) - Business timezone
- created_at: DateTimeField(auto_now_add=True)
- updated_at: DateTimeField(auto_now=True)

Relationships:
- users: Many-to-many through BusinessUserRole
- displays: One-to-many
- menus: One-to-many

Validation:
- subscription_tier must match actual limits
- colors must be valid hex codes
- timezone must be valid timezone string
```

#### User (extends Django AbstractUser)
```
Fields:
- id: UUID (primary key)
- email: EmailField(unique=True) - Login identifier
- first_name: CharField(max_length=150)
- last_name: CharField(max_length=150)
- phone: CharField(max_length=20, blank=True)
- is_email_verified: BooleanField(default=False)
- last_login_ip: GenericIPAddressField(null=True)
- failed_login_attempts: IntegerField(default=0)
- is_locked: BooleanField(default=False)
- locked_until: DateTimeField(null=True)
- created_at: DateTimeField(auto_now_add=True)
- updated_at: DateTimeField(auto_now=True)

Relationships:
- businesses: Many-to-many through BusinessUserRole

Validation:
- email must be unique across system
- phone must be valid format if provided
- account lockout after 5 failed attempts
```

#### BusinessUserRole
```
Fields:
- id: UUID (primary key)
- business: ForeignKey(BusinessAccount)
- user: ForeignKey(User)
- role: CharField(choices=['owner', 'manager', 'staff', 'readonly'])
- is_active: BooleanField(default=True)
- invited_by: ForeignKey(User, null=True) - Who sent invitation
- invited_at: DateTimeField(null=True)
- accepted_at: DateTimeField(null=True)
- created_at: DateTimeField(auto_now_add=True)

Relationships:
- business: Many-to-one
- user: Many-to-one
- invited_by: Many-to-one (self-referential)

Constraints:
- Unique together: (business, user)
- At least one owner per business
- Only owners can delete other owners
```

### Menu Management

#### Menu
```
Fields:
- id: UUID (primary key)
- business: ForeignKey(BusinessAccount) - Multi-tenant isolation
- name: CharField(max_length=255)
- description: TextField(blank=True)
- version: IntegerField(default=1) - Auto-incremented
- is_active: BooleanField(default=True)
- is_published: BooleanField(default=False)
- scheduled_publish_at: DateTimeField(null=True)
- layout_template: CharField(max_length=50, default='grid')
- custom_css: TextField(blank=True) - For enterprise customers
- background_color: CharField(max_length=7, default='#FFFFFF')
- text_color: CharField(max_length=7, default='#000000')
- font_family: CharField(max_length=100, default='Inter')
- created_by: ForeignKey(User)
- created_at: DateTimeField(auto_now_add=True)
- updated_at: DateTimeField(auto_now=True)

Relationships:
- business: Many-to-one
- categories: One-to-many
- displays: Many-to-many through DisplayMenuAssignment
- created_by: Many-to-one

Validation:
- name must be unique per business
- colors must be valid hex codes
- scheduled_publish_at must be future date
```

#### MenuCategory
```
Fields:
- id: UUID (primary key)
- menu: ForeignKey(Menu, on_delete=CASCADE)
- name: CharField(max_length=255)
- description: TextField(blank=True)
- image: ForeignKey(MediaAsset, null=True, blank=True)
- sort_order: IntegerField(default=0)
- is_visible: BooleanField(default=True)
- parent_category: ForeignKey('self', null=True, blank=True) - For subcategories
- created_at: DateTimeField(auto_now_add=True)
- updated_at: DateTimeField(auto_now=True)

Relationships:
- menu: Many-to-one
- image: Many-to-one (optional)
- items: One-to-many
- parent_category: Many-to-one (self-referential)

Validation:
- name must be unique per menu
- maximum 3 levels of nesting
- sort_order for display ordering
```

#### MenuItem
```
Fields:
- id: UUID (primary key)
- category: ForeignKey(MenuCategory, on_delete=CASCADE)
- name: CharField(max_length=255)
- description: TextField(blank=True)
- price: DecimalField(max_digits=10, decimal_places=2)
- image: ForeignKey(MediaAsset, null=True, blank=True)
- is_available: BooleanField(default=True)
- is_featured: BooleanField(default=False)
- sort_order: IntegerField(default=0)
- allergens: JSONField(default=list) - List of allergen codes
- dietary_flags: JSONField(default=list) - ['vegetarian', 'vegan', 'gluten-free', etc.]
- nutritional_info: JSONField(null=True, blank=True) - Calories, etc.
- preparation_time: IntegerField(null=True, blank=True) - Minutes
- created_at: DateTimeField(auto_now_add=True)
- updated_at: DateTimeField(auto_now=True)

Relationships:
- category: Many-to-one
- image: Many-to-one (optional)

Validation:
- name must be unique per category
- price must be positive
- allergens must be valid codes
- preparation_time must be positive if specified
```

### Display Management

#### DisplayDevice
```
Fields:
- id: UUID (primary key)
- business: ForeignKey(BusinessAccount) - Multi-tenant isolation
- device_id: CharField(max_length=255, unique=True) - Android device ID
- name: CharField(max_length=255) - User-friendly name
- location: CharField(max_length=255, blank=True) - Physical location
- status: CharField(choices=['online', 'offline', 'error', 'updating'])
- pairing_code: CharField(max_length=32, null=True) - For QR code pairing
- pairing_expires_at: DateTimeField(null=True)
- is_paired: BooleanField(default=False)
- last_heartbeat: DateTimeField(null=True)
- last_sync: DateTimeField(null=True)
- firmware_version: CharField(max_length=50, blank=True)
- android_version: CharField(max_length=50, blank=True)
- screen_resolution: CharField(max_length=20, blank=True) - e.g., "1920x1080"
- orientation: CharField(choices=['landscape', 'portrait'], default='landscape')
- network_info: JSONField(null=True) - WiFi/Ethernet details
- performance_stats: JSONField(null=True) - CPU, memory, storage
- error_log: JSONField(default=list) - Recent error messages
- created_at: DateTimeField(auto_now_add=True)
- updated_at: DateTimeField(auto_now=True)

Relationships:
- business: Many-to-one
- display_groups: Many-to-many through DisplayGroupMember
- menu_assignments: Many-to-many through DisplayMenuAssignment

Validation:
- device_id must be unique across system
- pairing_code expires after 10 minutes
- heartbeat determines online/offline status
```

#### DisplayGroup
```
Fields:
- id: UUID (primary key)
- business: ForeignKey(BusinessAccount)
- name: CharField(max_length=255)
- description: TextField(blank=True)
- sync_strategy: CharField(choices=['simultaneous', 'sequential'], default='simultaneous')
- created_at: DateTimeField(auto_now_add=True)
- updated_at: DateTimeField(auto_now=True)

Relationships:
- business: Many-to-one
- displays: Many-to-many through DisplayGroupMember

Validation:
- name must be unique per business
- maximum 3 displays per group
```

#### DisplayGroupMember
```
Fields:
- id: UUID (primary key)
- display_group: ForeignKey(DisplayGroup)
- display_device: ForeignKey(DisplayDevice)
- position: CharField(choices=['left', 'center', 'right'], default='center')
- is_primary: BooleanField(default=False) - Primary display for coordination
- created_at: DateTimeField(auto_now_add=True)

Relationships:
- display_group: Many-to-one
- display_device: Many-to-one

Constraints:
- Unique together: (display_group, display_device)
- Unique together: (display_group, position)
- Only one primary display per group
```

#### DisplayMenuAssignment
```
Fields:
- id: UUID (primary key)
- display_device: ForeignKey(DisplayDevice)
- menu: ForeignKey(Menu)
- assigned_at: DateTimeField(auto_now_add=True)
- assigned_by: ForeignKey(User)
- is_active: BooleanField(default=True)
- last_sync_attempt: DateTimeField(null=True)
- last_successful_sync: DateTimeField(null=True)
- sync_status: CharField(choices=['pending', 'syncing', 'success', 'error'])
- sync_error_message: TextField(blank=True)

Relationships:
- display_device: Many-to-one
- menu: Many-to-one
- assigned_by: Many-to-one

Validation:
- Only one active assignment per display
- Menu must belong to same business as display
```

### Media Management

#### MediaAsset
```
Fields:
- id: UUID (primary key)
- business: ForeignKey(BusinessAccount) - Multi-tenant isolation
- original_filename: CharField(max_length=255)
- file_type: CharField(choices=['image', 'video'])
- mime_type: CharField(max_length=100)
- file_size: IntegerField - Bytes
- width: IntegerField(null=True) - Original dimensions
- height: IntegerField(null=True)
- file_url: URLField - Original file URL
- thumbnail_url: URLField(null=True) - Optimized thumbnail
- display_url: URLField(null=True) - Display-optimized version
- alt_text: CharField(max_length=255, blank=True) - Accessibility
- upload_status: CharField(choices=['pending', 'processing', 'ready', 'error'])
- processing_error: TextField(blank=True)
- uploaded_by: ForeignKey(User)
- created_at: DateTimeField(auto_now_add=True)
- updated_at: DateTimeField(auto_now=True)

Relationships:
- business: Many-to-one
- uploaded_by: Many-to-one

Validation:
- file_size must not exceed limits (5MB images, 50MB videos)
- mime_type must be allowed format
- file_type must match mime_type category
```

### Analytics and Monitoring

#### AnalyticsEvent
```
Fields:
- id: UUID (primary key)
- business: ForeignKey(BusinessAccount) - Multi-tenant isolation
- event_type: CharField(max_length=100) - 'display_sync', 'menu_update', etc.
- entity_type: CharField(max_length=50) - 'display', 'menu', 'user', etc.
- entity_id: UUIDField - ID of related entity
- user: ForeignKey(User, null=True) - User who triggered event
- display_device: ForeignKey(DisplayDevice, null=True) - For display events
- event_data: JSONField(null=True) - Additional event context
- timestamp: DateTimeField(auto_now_add=True)
- ip_address: GenericIPAddressField(null=True)
- user_agent: TextField(null=True)

Relationships:
- business: Many-to-one
- user: Many-to-one (optional)
- display_device: Many-to-one (optional)

Indexes:
- (business, event_type, timestamp) - For business analytics
- (display_device, timestamp) - For display health monitoring
- (user, timestamp) - For user activity tracking
```

#### ApiToken
```
Fields:
- id: UUID (primary key)
- business: ForeignKey(BusinessAccount)
- name: CharField(max_length=255) - Token description
- key: CharField(max_length=255, unique=True) - API key
- permissions: JSONField - List of allowed operations
- is_active: BooleanField(default=True)
- expires_at: DateTimeField(null=True) - Optional expiration
- last_used_at: DateTimeField(null=True)
- created_by: ForeignKey(User)
- created_at: DateTimeField(auto_now_add=True)

Relationships:
- business: Many-to-one
- created_by: Many-to-one

Validation:
- key must be cryptographically secure
- permissions must be valid operation names
- name must be unique per business
```

## Database Indexes and Performance

### Critical Indexes
```sql
-- Multi-tenant queries
CREATE INDEX idx_menu_business_active ON menus(business_id, is_active);
CREATE INDEX idx_display_business_status ON display_devices(business_id, status);
CREATE INDEX idx_menuitem_category_available ON menu_items(category_id, is_available);

-- Real-time updates
CREATE INDEX idx_display_heartbeat ON display_devices(last_heartbeat) WHERE status = 'online';
CREATE INDEX idx_analytics_timestamp ON analytics_events(business_id, timestamp);

-- API performance
CREATE INDEX idx_user_email_active ON users(email) WHERE is_active = true;
CREATE INDEX idx_token_key_active ON api_tokens(key) WHERE is_active = true;
```

### Row-Level Security Policies
```sql
-- Automatic tenant isolation
CREATE POLICY business_isolation ON menus
    FOR ALL TO web_user
    USING (business_id = current_setting('app.current_business_id')::uuid);

CREATE POLICY display_isolation ON display_devices
    FOR ALL TO web_user  
    USING (business_id = current_setting('app.current_business_id')::uuid);
```

## State Transitions and Business Rules

### Display Device States
- **offline** → **online**: Successful heartbeat received
- **online** → **updating**: Menu sync initiated
- **updating** → **online**: Sync completed successfully
- **updating** → **error**: Sync failed
- **error** → **online**: Successful heartbeat after error resolved

### Menu Publishing Workflow
1. **Draft**: Menu created, editable
2. **Scheduled**: Publish time set, awaiting publication
3. **Published**: Live on assigned displays
4. **Archived**: Replaced by newer version

### User Role Hierarchy
- **Owner**: Full access, can manage other owners
- **Manager**: All except owner management and billing
- **Staff**: Menu editing, basic display monitoring
- **Read-Only**: View-only access to all data

This data model supports all functional requirements while maintaining data integrity, performance, and security through proper relationships, validation, and indexing strategies.