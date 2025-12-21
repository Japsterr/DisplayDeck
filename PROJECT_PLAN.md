# DisplayDeck Project Plan

> Status update — 2025-10-16
>
> The server is Delphi WebBroker + Indy (Linux) with FireDAC + PostgreSQL and MinIO for media.
> Swagger UI serves the OpenAPI v3 spec from `docs/openapi.yaml`.
>
> Key implemented endpoints include:
> - Auth: /auth/login, /auth/register
> - Orgs: /organizations (GET/POST), /organizations/{id} (GET)
> - Displays: /organizations/{orgId}/displays (GET/POST), /displays/{id} (GET/PUT/DELETE)
> - Campaigns: /organizations/{orgId}/campaigns (GET/POST), /campaigns/{id} (GET/PUT/DELETE)
> - Assignments: /displays/{id}/campaign-assignments (GET/POST), /campaign-assignments/{id} (PUT/DELETE)
> - Media: /organizations/{orgId}/media-files (GET/POST), /media-files/{id} (GET/PUT/DELETE), /media-files/upload-url, /media-files/{id}/download-url
> - Device/logging: /device/config, /device/logs, /playback-logs

## 1. Project Vision

To create a modern, flexible, and multi-tenant SaaS platform for digital signage. The system will allow users to manage and schedule media content for display on various screens, with robust analytics and support for multiple client types.

## 2. Core Features

*   **Multi-Tenant Account System:**
    *   **Organizations:** Each customer has their own isolated workspace.
    *   **Users & Roles:** Organizations can have multiple users with different permission levels (Owner, Content Manager, Viewer).

*   **Subscription & Billing:**
    *   **Plans:** Multiple subscription tiers (e.g., Free, Starter, Business) with defined limits.
    *   **Limits:** Plans will have limits on the number of displays, campaigns, and media storage.

*   **Content Management:**
    *   **Media Library:** Users can upload images and videos.
    *   **Campaigns:** Users can create "playlists" of media items, defining the order and duration for each item.
    *   **Orientation:** Campaigns are designed for either 'Landscape' or 'Portrait' displays.

*   **Display Management:**
    *   **Device Provisioning:** A simple process for registering new displays using a QR code scanned by a mobile app.
    *   **Device Properties:** Each display has a name and a fixed orientation ('Landscape' or 'Portrait').
    *   **Offline Capability:** Displays will cache content and continue to play even if the internet connection is lost.

*   **Scheduling:**
    *   **Simple Scheduling:** Assign campaigns to displays.
    *   **Advanced Scheduling:** Campaigns can be scheduled to run at specific times, on specific days, or within a date range.

*   **Analytics (Proof of Play):**
    *   **Playback Logging:** The system will track every time a media item is played on a specific display.
    *   **Reporting:** Provide analytics on media performance, campaign usage, and display activity.

*   **Multi-Platform Clients:**
    *   **Android TV App:** A dedicated client for Android-based smart TVs and devices.
    *   **Delphi Client:** A reusable component for displaying content within native Delphi (VCL/FMX) applications, such as on a second monitor for a POS system.

## 3. Technology Stack

*   **Language:** Delphi (Object Pascal)
*   **API Framework:** Delphi WebBroker + Indy
*   **Data Access:** FireDAC (direct SQL, no ORM)
*   **Database:** PostgreSQL (running in Docker)
*   **Object Storage:** MinIO (S3-compatible, running in Docker)
*   **Deployment:**
    *   **Development Host:** Windows (VCL Standalone Server)
    *   **Production Host:** Linux (as an Apache Module, deployed via Docker)

## 4. Development Roadmap

This roadmap is divided into phases to manage development effectively.

### Phase 1: Core API Development (MVP)

*   [X] **Task 1:** Set up the local development environment.
    *   [X] Create `docker-compose.yml` for PostgreSQL and MinIO services.
    *   [X] Create initial database schema script (`schema.sql`).
*   [X] **Task 2:** Create the initial Delphi project structure and establish database connectivity.
    *   [X] Create the initial server project.
    *   [X] Commit initial project files to the Git repository.
    *   [X] Successfully connect the Delphi server to the PostgreSQL database.
*   [X] **Task 3:** Define core data models (Entities) using pure Delphi classes (moved from ORM-based mapping to FireDAC).
    *   [X] `TOrganization`, `TUser`
    *   [X] `TPlan`, `TSubscription`
    *   [X] `TMediaFile`, `TCampaign`, `TCampaignItem`
    *   [X] `TDisplay`, `TSchedule`, `TDisplayCampaign`
    *   [X] `TPlaybackLog`
*   [X] **Task 4:** Implement API Endpoints.
    *   [X] Campaign Management (CRUD) - Full implementation with FireDAC
    *   [X] User Management (CRUD) - Full implementation with FireDAC  
    *   [X] Organization Management (CRUD) - Full implementation with FireDAC
    *   [X] Display Management (CRUD) - Full implementation with FireDAC
    *   [X] Media File Management (CRUD) - Full implementation with FireDAC
    *   [X] Plan Management (CRUD) - Full implementation with FireDAC
    *   [X] Subscription Management (CRUD) - Full implementation with FireDAC
    *   [X] Role Management (CRUD) - Predefined roles implementation
    *   [X] Playback Log Management (CRUD) - Full implementation with FireDAC
    *   [X] Campaign Item Management (CRUD) - Full implementation with FireDAC
    *   [X] Display Campaign Management (CRUD) - Full implementation with FireDAC
    * [X] Authentication (`/auth/register`, `/auth/login`) - JWT-based with password hashing
    * [X] Media Upload Workflow (using pre-signed URLs with MinIO) - Pre-signed URL generation
    * [X] Device-specific endpoints (`/device/config`, `/device/logs`) - Configuration and logging endpoints
    

### Phase 2: Deployment & Infrastructure

*   [ ] **Task 5:** Prepare for Linux deployment.
    *   [ ] Create `Dockerfile` for the PAServer.
    *   [ ] Configure Delphi IDE with a Linux Connection Profile.
    *   [ ] Keep the Linux build pipeline and Docker packaging up to date.
*   [ ] **Task 6:** Containerize the API for production.
    *   [ ] Create `Dockerfile` for the final API server (Apache + .so module).
*   [ ] **Task 7:** Implement a robust database migration strategy.
    *   [ ] Use versioned SQL migration scripts for schema updates.
*   [ ] **Task 8:** (Optional) Set up a CI/CD pipeline on GitHub Actions to automatically build the Docker image on push.

### Phase 3: Client Development

*   [ ] **Task 9:** Develop a simple web-based admin panel for managing the system.
*   [ ] **Task 10:** Develop the Android TV display client.
*   [ ] **Task 11:** Develop the reusable Delphi VCL/FMX display client component.

### Phase 4: Advanced Features & Monetization

*   [ ] **Task 12:** Integrate with a payment provider (e.g., Stripe) to handle subscriptions.
*   [ ] **Task 13:** Build out the analytics dashboard in the web admin panel.
*   [ ] **Task 14:** Implement the advanced scheduling features (recurring schedules, etc.).

### API Notes

The repository previously contained a legacy server/client prototype. Those artifacts were removed to reduce confusion; the supported API is the WebBroker REST API documented in `docs/openapi.yaml`.
