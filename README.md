# WordPress Docker Setup

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

## Table of Contents

1. [Quickstart](#quickstart)
2. [Usage](#usage)
3. [Files in Repository](#files-in-repository)

## Quickstart

Prerequisite:

- Docker Engine with Compose plugin

Steps:

1. Clone the repository:

    ```bash
    git clone
    git@github.com:ralfs-devs/wordpress.git
    cd wordpress
    ```

2. Create your environment file from the template and set real credentials:

    ```bash
    cp example.env .env
    nano .env
    ```

    **Note:**  
    `MYSQL_PASSWORD` and `WORDPRESS_DB_PASSWORD` must be identical.

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

- Change the published port by editing the `ports` mapping of the  
`wordpress` service.
- Adjust database credentials in `.env` before the first start. Note:  
MySQL applies  
these values only on initial volume creation; after changing them,  
recreate the database volume.
- The `wordpress` service uses a pinned version tag (`wordpress:7.1.3
-apache`) for reproducible deployments. Both images are deliberately  
pinned instead of using floating tags like `latest` to prevent  
uncontrolled version drift.
- To upgrade WordPress, change the image tag in `docker-compose.yaml`  
and run `docker compose up -d`.  
- Database images use fixed minor version tags (`mysql:8.0`)  
to avoid incompatible major version jumps.

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

## Files in Repository

| File                   | Purpose                                                  |
|------------------------|--------------------------------------------------------- |
| `docker-compose.yaml`  | Orchestration of the wordpress and db services           |
| `example.env`          | Template for environment credentials (placeholders only) |
| `.gitignore`           | Excludes secrets, volume data, and editor files          |
| `README.md`            | This documentation                                       |
