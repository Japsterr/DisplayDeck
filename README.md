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

The project is now successfully set up. The Delphi server can connect to the PostgreSQL database running in Docker.

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
3.  **Start Backend Services:**
    Use Docker Compose to start the PostgreSQL database.
    ```bash
    docker-compose up -d
    ```

4.  **Run the API Server:**
    The Delphi XData server project is located in the `Server/` directory. Open `Server/DisplayDeck.dproj` in the Delphi IDE, compile, and run the project. The server will start and automatically connect to the database.
