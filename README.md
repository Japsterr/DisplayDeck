# DisplayDeck API

This is the backend API for DisplayDeck, a digital signage SaaS platform.

## Overview

DisplayDeck is a platform for managing and displaying digital content on various screens, such as TVs and customer-facing POS displays. This repository contains the source code for the backend API that powers the entire system.

## Technology Stack

*   **Language:** Delphi (Object Pascal)
*   **API Framework:** TMS XData
*   **ORM Framework:** TMS Aurelius
*   **Database:** PostgreSQL (running in Docker)
*   **Object Storage:** MinIO (S3-compatible, running in Docker)
*   **Deployment Target:** Linux via Docker (as an Apache Module)

## Getting Started

This project is currently in the initial setup phase.

### Prerequisites

*   Embarcadero Delphi (Architect Edition recommended for Linux deployment)
*   Docker Desktop
*   Git for version control

### Development Workflow

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/Japsterr/DisplayDeck.git
    ```
2.  **Navigate to the project directory:**
    ```bash
    cd DisplayDeck
    ```
3.  **Backend Services:**
    The backend dependencies (PostgreSQL, MinIO) are intended to be run via Docker. A `docker-compose.yml` file will be added to manage this environment.

4.  **API Server:**
    The Delphi XData server project is located in the `Server/` directory. Open `Server/DisplayDeck.dproj` in the Delphi IDE to get started.
