# Github Backup

Based on the work of [Richard Bairwell](https://github.com/bairwell/github2synology).

This script offers two methods to save your Github repositories:

- An advanced method with Node.js *(Linux/MacOS/Windows)*.
- A simple `sh` script designed to run on the Synology DS range of file storage servers to backup all repositories (and wikis) for a user from Github *(Linux/MacOS/WSL)*.

Bonus in `sh` version:
- You can auto-push your backup to a Gitea server

## With Docker

```bash
# node.js version
docker run --rm -v '/mnt/x/backups':/mnt/backups --env GITHUB_BACKUP_PATH=/mnt/backups --env GITHUB_BACKUP_USER=[company] --env GITHUB_BACKUP_TOKEN=[YOUR TOKEN] ghcr.io/creadigme/github-backup:0.1.0
```

```bash
# bin/sh version
docker run --rm -v '/mnt/x/backups':/mnt/backups --env GITHUB_BACKUP_PATH=/mnt/backups --env GITHUB_BACKUP_USER=[company] --env GITHUB_BACKUP_TOKEN=[YOUR TOKEN] ghcr.io/creadigme/github-backup-sh:0.1.0
```

## Prerequist

- Ensure you have `git` installed on the Server/Synology.

> Note: on DSM Synology - this can be download from the **SynoCommunity**.

- Now login to Github and go to [Fine-grained personal access tokens](https://github.com/settings/tokens?type=beta) and create a fine-grained token with the following repositories permissions:
    - Read access to code and metadata

- Add this token as environment variable `GITHUB_BACKUP_TOKEN` (`GITHUB_BACKUP_TOKEN="[PUT YOUR TOKEN HERE BETWEEN THE QUOTES]"`).
- Add the target github name as environment variable `GITHUB_BACKUP_USER` (`GITHUB_BACKUP_USER="[PUT THE TARGET USERNAME]"`).
- Ensure the environment variable `GITHUB_BACKUP_PATH` backup path is correct and set (`GITHUB_BACKUP_PATH="/volume1/serverBackups/github/backup"`).

## Node.js way

### Prerequist

- Ensure you have `node.js 18 (or later)` installed.

> Note: on DSM Synology - this can be download from the **SynoCommunity**.

### Installation

- Copy `./build/github-backup.js` over to your Synology/Server/[...].

> Note: on DSM Synology - all via SSH.

### Usage

```sh
# Without token (public repositories)
GITHUB_BACKUP_PATH=./backups GITHUB_BACKUP_USER=microsoft node ./github-backup.js

# With token (public+private repositories)
GITHUB_BACKUP_PATH=./backups GITHUB_BACKUP_TOKEN=XXXX node ./github-backup.js
```

## /bin/sh way

### Prerequist

- **cUrl**
- [jq](https://stedolan.github.io/jq/) *but these seem standard on Synologys*.

### Installation

- Copy the script (`./scripts/github-backup.sh`) over to your Synology/Server/[...].

> Note: on DSM Synology - all via SSH.

### Usage

```sh
# Without token (public repositories)
GITHUB_BACKUP_PATH=./backups GITHUB_BACKUP_USER=microsoft ./github-backup.sh

# With token (public+private repositories)
GITHUB_BACKUP_PATH=./backups GITHUB_BACKUP_TOKEN=XXXX ./github-backup.sh
```

## Bonus - Gitea

### Prerequist

- Generate a token with this command:

```bash
curl -H "Content-Type: application/json" -d '{\"name\":\"<Token Name>\"}' -u <user>:<password> http://<gitea-host>/api/v1/users/<user>/tokens
# {"id":1,"name":"Token Name","sha1":"XXXXX","token_last_eight":"YYYYY"}
# The token: the sha1 value.
```

### Auto push to Gitea

```bash
GITHUB_BACKUP_PATH=./backups GITHUB_BACKUP_USER=creadigme GITHUB_BACKUP_TOKEN=[GITHUB_TOKEN] GITEA_URL=[GITEA_URL] GITEA_USER=[GITEA_USER] GITEA_API_TOKEN=[GITEA_TOKEN] EXTRA_REPO_STEP=./scripts/mirror-2-gitea.sh ./scripts/github-backup.sh
```
