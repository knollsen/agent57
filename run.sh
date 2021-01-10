#!/usr/bin/env bash

# Get path of root directory of this repository (needed to mount repository
# as docker volume)
REPO_ROOT_DIR=$(cd $(dirname "$0"); pwd)

# -u $(id -u):$(id -g) \
docker run --rm -it \
	-v "$REPO_ROOT_DIR:/code" \
	--workdir /code \
	mkerschbaumer/openai-gym bash
