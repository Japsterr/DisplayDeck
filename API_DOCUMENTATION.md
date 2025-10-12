# DisplayDeck REST API Documentation

## Overview

DisplayDeck provides a comprehensive REST API for digital signage management, built with TMS XData and Delphi. The API enables user authentication, media file management, device control, and campaign management for FireMonkey mobile applications.

**Base URL:** `http://localhost:2001/tms/xdata`

**Authentication:** JWT Bearer tokens (obtained via AuthService)

**Content-Type:** `application/json`

---

## 🔐 AuthService - User Authentication

### Register User
Create a new user account and organization.

**Endpoint:** `POST /AuthService/Register`

**Request Body:**
```json
{
  "Email": "user@example.com",
  "Password": "securepassword123",
  "OrganizationName": "My Company"
}
```

**Response (Success):**
```json
{
  "Success": true,
  "Token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "User": {
    "Id": 1,
    "Email": "user@example.com",
    "OrganizationId": 1
  },
  "Message": "User registered successfully"
}
```

**Response (Error):**
```json
{
  "Success": false,
  "Message": "Email already exists"
}
```

**Status Codes:**
- `200` - Success
- `400` - Validation error
- `500` - Server error

### Login User
Authenticate existing user and receive JWT token.

**Endpoint:** `POST /AuthService/Login`

**Request Body:**
```json
{
  "Email": "user@example.com",
  "Password": "securepassword123"
}
```

**Response (Success):**
```json
{
  "Success": true,
  "Token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "User": {
    "Id": 1,
    "Email": "user@example.com",
    "OrganizationId": 1
  }
}
```

**Response (Error):**
```json
{
  "Success": false,
  "Message": "Invalid email or password"
}
```

---

## 📁 MediaFileService - File Management

### Generate Upload URL
Get pre-signed URL for secure file upload to MinIO.

**Endpoint:** `POST /MediaFileService/GenerateUploadUrl`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Request Body:**
```json
{
  "FileName": "campaign_video.mp4",
  "ContentType": "video/mp4",
  "FileSize": 10485760
}
```

**Response:**
```json
{
  "UploadUrl": "https://minio.example.com/displaydeck-bucket/...",
  "FileId": "abc123",
  "ExpiresAt": "2025-10-12T15:30:00Z"
}
```

### Generate Download URL
Get pre-signed URL for secure file download from MinIO.

**Endpoint:** `POST /MediaFileService/GenerateDownloadUrl`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Request Body:**
```json
{
  "FileId": "abc123"
}
```

**Response:**
```json
{
  "DownloadUrl": "https://minio.example.com/displaydeck-bucket/...",
  "ExpiresAt": "2025-10-12T15:30:00Z"
}
```

### Get Upload URL (Alternative)
Alternative method for upload URL generation.

**Endpoint:** `GET /MediaFileService/GetUploadUrl?fileName={name}&contentType={type}`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "Url": "https://minio.example.com/displaydeck-bucket/...",
  "Fields": {
    "key": "uploads/file.mp4",
    "policy": "...",
    "signature": "..."
  }
}
```

---

## 📱 DeviceService - Device Management

### Get Device Configuration
Retrieve configuration for a specific device.

**Endpoint:** `POST /DeviceService/GetConfig`

**Headers:**
```
Authorization: Bearer <jwt_token>
X-Device-Token: <provisioning_token>
```

**Request Body:**
```json
{
  "DeviceId": "device123"
}
```

**Response:**
```json
{
  "DeviceId": "device123",
  "OrganizationId": 1,
  "Config": {
    "DisplayResolution": "1920x1080",
    "RefreshInterval": 300,
    "Timezone": "America/New_York"
  },
  "Campaigns": [
    {
      "Id": 1,
      "Name": "Morning Announcements",
      "Priority": 1
    }
  ]
}
```

### Send Device Log
Submit log entry from device.

**Endpoint:** `POST /DeviceService/SendLog`

**Headers:**
```
Authorization: Bearer <jwt_token>
X-Device-Token: <provisioning_token>
```

**Request Body:**
```json
{
  "DeviceId": "device123",
  "Level": "INFO",
  "Message": "Campaign playback started",
  "Timestamp": "2025-10-12T14:30:00Z",
  "Metadata": {
    "CampaignId": 1,
    "FileId": "abc123"
  }
}
```

**Response:**
```json
{
  "Success": true,
  "LogId": 12345
}
```

---

## 📢 CampaignService - Campaign Management

### Get Campaigns
Retrieve all campaigns for organization.

**Endpoint:** `GET /CampaignService/GetCampaigns`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "Campaigns": [
    {
      "Id": 1,
      "Name": "Welcome Message",
      "Description": "Welcome visitors to our office",
      "IsActive": true,
      "CreatedAt": "2025-10-01T09:00:00Z",
      "Items": [
        {
          "Id": 1,
          "MediaFileId": "file123",
          "Duration": 30,
          "Order": 1
        }
      ]
    }
  ]
}
```

### Create Campaign
Create a new campaign.

**Endpoint:** `POST /CampaignService/CreateCampaign`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Request Body:**
```json
{
  "Name": "New Campaign",
  "Description": "Campaign description",
  "Items": [
    {
      "MediaFileId": "file123",
      "Duration": 30,
      "Order": 1
    }
  ]
}
```

---

## 🖥️ DisplayService - Display Management

### Get Displays
Get all displays for organization.

**Endpoint:** `GET /DisplayService/GetDisplays`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "Displays": [
    {
      "Id": 1,
      "Name": "Lobby Display",
      "Location": "Main Lobby",
      "Resolution": "1920x1080",
      "IsActive": true,
      "LastSeen": "2025-10-12T14:25:00Z"
    }
  ]
}
```

### Register Display
Register a new display device.

**Endpoint:** `POST /DisplayService/RegisterDisplay`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Request Body:**
```json
{
  "Name": "New Display",
  "Location": "Conference Room A",
  "Resolution": "3840x2160",
  "DeviceToken": "prov_token_123"
}
```

---

## 📊 PlaybackLogService - Analytics

### Get Playback Logs
Retrieve playback analytics data.

**Endpoint:** `GET /PlaybackLogService/GetPlaybackLogs?startDate={date}&endDate={date}`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "Logs": [
    {
      "Id": 1,
      "DisplayId": 1,
      "CampaignId": 1,
      "MediaFileId": "file123",
      "PlayedAt": "2025-10-12T14:30:00Z",
      "Duration": 30,
      "CompletionRate": 100
    }
  ]
}
```

---

## 🏢 OrganizationService - Organization Management

### Get Organization Info
Get current organization details.

**Endpoint:** `GET /OrganizationService/GetOrganization`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "Id": 1,
  "Name": "My Company",
  "CreatedAt": "2025-10-01T09:00:00Z",
  "Subscription": {
    "PlanId": 2,
    "Status": "Active",
    "CurrentPeriodEnd": "2025-11-01T00:00:00Z"
  }
}
```

---

## 💳 PlanService - Subscription Plans

### Get Available Plans
List all available subscription plans.

**Endpoint:** `GET /PlanService/GetPlans`

**Response:**
```json
{
  "Plans": [
    {
      "Id": 1,
      "Name": "Free",
      "Price": 0.00,
      "MaxDisplays": 1,
      "MaxCampaigns": 2,
      "MaxMediaStorageGB": 1
    },
    {
      "Id": 2,
      "Name": "Starter",
      "Price": 9.99,
      "MaxDisplays": 5,
      "MaxCampaigns": 10,
      "MaxMediaStorageGB": 10
    }
  ]
}
```

---

## 👥 UserService - User Management

### Get Users
Get all users in organization.

**Endpoint:** `GET /UserService/GetUsers`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "Users": [
    {
      "Id": 1,
      "Email": "admin@company.com",
      "Role": "Owner",
      "CreatedAt": "2025-10-01T09:00:00Z"
    }
  ]
}
```

---

## 🔑 RoleService - Role Management

### Get Roles
Get available user roles.

**Endpoint:** `GET /RoleService/GetRoles`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "Roles": [
    {
      "Id": 1,
      "Name": "Owner",
      "Permissions": ["read", "write", "admin"]
    },
    {
      "Id": 2,
      "Name": "ContentManager",
      "Permissions": ["read", "write"]
    }
  ]
}
```

---

## 💰 SubscriptionService - Billing

### Get Subscription
Get current subscription details.

**Endpoint:** `GET /SubscriptionService/GetSubscription`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "Subscription": {
    "Id": 1,
    "PlanId": 2,
    "Status": "Active",
    "CurrentPeriodStart": "2025-10-01T00:00:00Z",
    "CurrentPeriodEnd": "2025-11-01T00:00:00Z",
    "TrialEndDate": null
  }
}
```

---

## 📋 CampaignItemService - Campaign Items

### Get Campaign Items
Get items within a campaign.

**Endpoint:** `GET /CampaignItemService/GetCampaignItems?campaignId={id}`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "Items": [
    {
      "Id": 1,
      "CampaignId": 1,
      "MediaFileId": "file123",
      "Duration": 30,
      "Order": 1,
      "Transition": "fade"
    }
  ]
}
```

---

## 📺 DisplayCampaignService - Display Assignments

### Get Display Campaigns
Get campaigns assigned to a display.

**Endpoint:** `GET /DisplayCampaignService/GetDisplayCampaigns?displayId={id}`

**Headers:**
```
Authorization: Bearer <jwt_token>
```

**Response:**
```json
{
  "Assignments": [
    {
      "Id": 1,
      "DisplayId": 1,
      "CampaignId": 1,
      "Priority": 1,
      "Schedule": {
        "StartTime": "09:00",
        "EndTime": "17:00",
        "DaysOfWeek": ["monday", "tuesday", "wednesday", "thursday", "friday"]
      }
    }
  ]
}
```

---

## Error Handling

All endpoints return errors in the following format:

```json
{
  "error": {
    "code": "ErrorCode",
    "message": "Human-readable error message"
  }
}
```

**Common Error Codes:**
- `Unauthorized` - Invalid or missing JWT token
- `Forbidden` - Insufficient permissions
- `NotFound` - Resource not found
- `ValidationError` - Invalid request data
- `ServerError` - Internal server error

---

## Authentication Flow

1. **Register/Login** → Receive JWT token
2. **Include token** in `Authorization: Bearer <token>` header
3. **Access protected endpoints** with valid token
4. **Token expires** → Login again to get new token

---

## File Upload Flow

1. **Get upload URL** from MediaFileService
2. **Upload file directly** to MinIO using pre-signed URL
3. **File stored securely** in organization's bucket
4. **Use download URL** to retrieve file when needed

---

## Device Registration Flow

1. **Generate provisioning token** (admin function)
2. **Device receives token** during setup
3. **Device calls GetConfig** with token to get configuration
4. **Device sends logs** using SendLog endpoint
5. **Device plays campaigns** based on configuration

This API provides complete backend functionality for digital signage management and is ready for FireMonkey mobile app integration.</content>
<parameter name="filePath">C:\DisplayDeck\API_DOCUMENTATION.md