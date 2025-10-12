# DisplayDeck Project Plan

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
*   **API Framework:** TMS XData (with Swagger/OpenAPI support)
*   **ORM Framework:** TMS Aurelius
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
    *   [X] Create the `TMS XData VCL Server` project.
    *   [X] Commit initial project files to the Git repository.
    *   [X] Successfully connect the Delphi server to the PostgreSQL database.
*   [ ] **Task 3:** Define core data models (Entities) using TMS Aurelius.
    *   [ ] `TOrganization`, `TUser`, `TRole`
    *   [ ] `TPlan`, `TSubscription`
    *   [ ] `TMediaFile`, `TCampaign`, `TCampaignItem`
    *   [ ] `TDisplay`, `TSchedule`, `TDisplayCampaign`
    *   [ ] `TPlaybackLog`
*   [ ] **Task 4:** Implement API Endpoints.
    *   [ ] Authentication (`/auth/register`, `/auth/login`).
    *   [ ] Campaign Management (CRUD).
    *   [ ] Display Management (CRUD & Provisioning).
    *   [ ] Media Upload Workflow (using pre-signed URLs with MinIO).
    *   [ ] Device-specific endpoints (`/device/config`, `/device/logs`).

### Phase 2: Deployment & Infrastructure

*   [ ] **Task 5:** Prepare for Linux deployment.
    *   [ ] Create `Dockerfile` for the PAServer.
    *   [ ] Configure Delphi IDE with a Linux Connection Profile.
    *   [ ] Create the `TMS XData Web Application` project targeting Apache/Linux.
*   [ ] **Task 6:** Containerize the API for production.
    *   [ ] Create `Dockerfile` for the final API server (Apache + .so module).
*   [ ] **Task 7:** Implement a robust database migration strategy.
    *   [ ] Transition from the initial `schema.sql` to using Aurelius `TDatabaseManager` for updates.
*   [ ] **Task 8:** (Optional) Set up a CI/CD pipeline on GitHub Actions to automatically build the Docker image on push.

### Phase 3: Client Development

*   [ ] **Task 9:** Develop a simple web-based admin panel for managing the system.
*   [ ] **Task 10:** Develop the Android TV display client.
*   [ ] **Task 11:** Develop the reusable Delphi VCL/FMX display client component.

### Phase 4: Advanced Features & Monetization

*   [ ] **Task 12:** Integrate with a payment provider (e.g., Stripe) to handle subscriptions.
*   [ ] **Task 13:** Build out the analytics dashboard in the web admin panel.
*   [ ] **Task 14:** Implement the advanced scheduling features (recurring schedules, etc.).
