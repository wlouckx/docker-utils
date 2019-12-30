# docker-utils
Own made docker utilities to simplify setting up an environment. Intended for personal use but free for all.

## Scripts
This repo contains the following scripts with a little description. For more details, like usage etc, refer to the comment section in the beginning of each script
* **env/secret_init.sh:** Get passwords/certificates from bitwarden vault and adds them as docker secret
* **env/docker_start.sh:** Take care of the pre-reqs (eg git pull, secrets with secret_init.sh) and start a docker stack. Requires a docker-compose.yml file.

## Disclaimer
This repo contains scripts that I use in my own environment. These might not be usable for other specific cases and might break something. Always check what you're about to do and be carefull :).
