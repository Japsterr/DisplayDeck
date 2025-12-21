# Dockerized Delphi PAServer (Linux toolchain via Docker)

This repo includes a Docker container that runs Embarcadero **PAServer** so you can compile the Linux64 target from **RAD Studio on Windows**, without maintaining a separate Linux VM.

## Prereqs

- Docker Desktop (Windows)
- RAD Studio installed (you must obtain PAServer from your RAD Studio installation)

## 1) Put the PAServer tarball in place

Copy the PAServer tarball from your RAD Studio install media to:

- `paserver/PAServer-Linux-64.tar.gz`

The container entrypoint also accepts these filenames:

- `paserver/PAServer_Linux_64.tar.gz`
- `paserver/LinuxPAServer*.tar.gz`

## 2) Start PAServer (fresh)

From the repo root:

```powershell
# Stop and delete any previous containers/volumes for a clean slate
docker compose down -v

# Start only the PAServer container
docker compose up -d --build paserver

# Confirm it is running
docker ps --filter "name=displaydeck-paserver"
```

PAServer is published to your machine as:

- Host: `127.0.0.1`
- Port: `49999` (mapped to container port `64211`)
- Password: `displaydeck` (see `docker-compose.yml`)

If you need to change password/port, edit the `paserver` service env vars in `docker-compose.yml`.

## 3) Configure RAD Studio to use the Dockerized PAServer

High level (menu names vary slightly by RAD Studio version):

1. Open **Tools → Options → Deployment → SDK Manager**
2. Add a new **Linux 64-bit** SDK / Connection Profile
3. Set:
   - Host: `127.0.0.1`
   - Port: `49999`
   - Password: `displaydeck`
4. Test connection, then install/refresh the SDK.

## 4) Build the Linux server binary

Build the Linux target for the server project so the output binary exists at:

- `Server/Linux/DisplayDeck.WebBroker`

Once that file exists (and is up-to-date), you can run the full stack locally via Docker.
