# DisplayDeck Campaign Manager Mobile App

A FireMonkey mobile application for managing digital signage campaigns, media files, and display devices through the DisplayDeck REST API.

## Features

- **User Authentication**: Login and registration with JWT tokens
- **Campaign Management**: Create, edit, and manage digital signage campaigns
- **Media Library**: Upload and manage media files (images, videos)
- **Display Management**: Register and monitor display devices
- **Cross-Platform**: Supports iOS and Android devices

## Requirements

- Delphi 11 or later with FireMonkey support
- DisplayDeck server running and accessible
- Internet connection for API communication

## Setup

1. **Configure API Endpoint**:
   - Open `uApiClient.pas`
   - Update `FBaseUrl` to point to your DisplayDeck server
   - Default: `http://localhost:2001/tms/xdata`

2. **Build the Application**:
   - Open `CampaignManager.dpr` in Delphi IDE
   - Select target platform (iOS or Android)
   - Build and deploy to device/emulator

## Usage

1. **Launch the App**: The login screen appears first
2. **Register/Login**: Create account or login with existing credentials
3. **Navigate Tabs**:
   - **Campaigns**: View and manage campaigns
   - **Media**: Upload and browse media files
   - **Displays**: Monitor connected display devices
   - **Settings**: App configuration and logout

## API Integration

The app communicates with the DisplayDeck server via REST API:

- **Authentication**: JWT-based login/registration
- **Campaigns**: CRUD operations for campaign management
- **Media Files**: Upload via pre-signed URLs to MinIO
- **Displays**: Device registration and status monitoring

## Architecture

- **uApiClient.pas**: Singleton API client for all HTTP requests
- **uEntities.pas**: Data models matching server API
- **uMainForm.pas**: Main navigation and tab management
- **uLoginForm.pas**: Authentication interface
- **Tab Forms**: Specialized forms for each feature area

## Development Notes

- Uses FireMonkey framework for cross-platform UI
- Implements REST client for API communication
- Supports camera and photo library access for media upload
- JWT tokens stored in memory during session

## Troubleshooting

- **Connection Issues**: Verify server URL and network connectivity
- **Authentication Errors**: Check credentials and server status
- **Media Upload Failures**: Ensure MinIO service is running
- **Build Errors**: Verify all required units are included in DPR file