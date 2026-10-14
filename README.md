# WordPress Docker Setup

## Table of Contents

1. [Description](#description)
2. [Quickstart](#quickstart)
3. [Usage](#usage)
4. [Automated Testing](#automated-testing)
5. [Files in Repository](#files-in-repository)

## Description

This repository contains a Docker Compose setup for deploying  
a self-hosted WordPress instance.

The infrastructure consists of two services:

- **wordpress** — official WordPress image (Apache + PHP),  
exposed on host port 8080
- **db** — MySQL 8.0, internal service without host exposure,  
data persisted in a Docker volume

Purpose: development and testing environment for DevSecOps training,  
demonstrating container orchestration, secret handling via environment files,  
persistent storage, and automatic restart policies.

## Quickstart

Prerequisites:

- Docker Engine with Compose plugin
- Git
- A reachable server or VM

Steps:

1. Clone the repository:

    ```bash
    git clone -b feature/wordpress-setup \
    git@github.com:ralfs-devs/wordpress.git
    cd wordpress
    ```

2. Create your environment file from the template and set real credentials:

    ```bash
    cp example.env .env
    nano .env
    ```

   Important: `MYSQL_PASSWORD` and `WORDPRESS_DB_PASSWORD` must be identical.

3. Start the stack:

    ```bash
    docker compose up
    ```

4. Open `http://<server-ip>:8080` in a browser and complete  
the WordPress installation.

## Usage

Configuration:

- All credentials are managed via `.env` (never committed; excluded by `.gitignore`).
- `example.env` serves as a template with placeholder values only.
- Both services communicate inside the isolated Docker network `wordpress_net`.
- WordPress files and database contents persist in the  
named volumes `wp_data` and `db_data`.

Customization:

- Change the published port by editing the `ports` mapping of the `wordpress` service.
- Adjust database credentials in `.env` before the first start. Note: MySQL applies  
these values only on initial volume creation; after changing them,  
recreate the database volume.
- Replace `wordpress:latest` with a pinned version tag for reproducible deployments.

Operations:

```bash
docker compose up        # start the stack
```

```bash
docker compose down      # stop and remove containers (volumes are kept)
```

```bash
docker compose logs      # view service logs
```

## Automated Testing

The script `tests/check_setup.sh` validates the running setup:

```bash
./tests/check_setup.sh http://<server-ip>:8080
```

Checks performed:

1. Service availability (HTTP status 200 or 302)
2. Containers are running
3. Persistence volumes exist
4. Restart policy is configured

## Files in Repository

| File                   | Purpose                                                  |
|------------------------|--------------------------------------------------------- |
| `docker-compose.yaml`  | Orchestration of the wordpress and db services           |
| `example.env`          | Template for environment credentials (placeholders only) |
| `.gitignore`           | Excludes secrets, volume data, and editor files          |
| `tests/check_setup.sh` | Automated validation script                              |
| `README.md`            | This documentation                                       |
