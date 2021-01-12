#!/usr/bin/env bash

function usage() {
	echo "$0 <VM instance IP> <algorithm> [ssh-key-file]"
	echo "The first two parameters are required and the third one (ssh key file) is optional."
	echo "e.g. $0 123.456.789.123 agent57 ~/.ssh/id_ed25519"
	echo "e.g. $0 123.456.789.123 dqn ~/.ssh/id_ed25519"
	echo
	echo "The default username can be overridden by setting SSH_USERNAME"
}

# Display help if explicitly required or nothing is passed
if [[ "$1" == "--help" || -z "$1" ]]; then
	usage
	exit 0
fi

VM_IP=$1
ALGORITHM=$2
SSH_KEY_FILE=$3

# Add SSH key if provided
# -n means non-empty
if [ -n "$SSH_KEY_FILE" ]; then
	ssh-add "$SSH_KEY_FILE" || exit
fi

# -z means zero -> tests if username is empty
if [ -z "$SSH_USERNAME" ]; then
	SSH_USERNAME=azureuser
fi

echo "Try connecting to $VM_IP using the username '$SSH_USERNAME'"
echo

echo "Installing docker on machine"
TARGET="$SSH_USERNAME@$VM_IP"
ssh "$TARGET" -- "sudo apt update && sudo apt install -y docker.io git zip" || exit

echo "Downloading required docker image"
ssh "$TARGET" -- sudo docker pull mkerschbaumer/openai-gym || exit

if [ -z "$GIT_REPO" ]; then
	GIT_REPO=https://github.com/knollsen/agent57.git
fi
echo "Using git repo '$GIT_REPO' (set GIT_REPO to override)"

# Temporary directory for the cloned repository
echo "Cloning repo containing the code"
ssh "$TARGET" -- "sudo rm -fr repo && git clone $GIT_REPO repo" || exit

if [ -z "$GIT_BRANCH" ]; then
	GIT_BRANCH=pong
fi
echo "Checking out git branch '$GIT_BRANCH' (set GIT_BRANCH to override)"
ssh "$TARGET" -- "cd repo && git checkout -q $GIT_BRANCH && cd .." || exit

# Construct algorithm-specific parts of docker run command
if [ "$ALGORITHM" == "agent57" ]; then
	ALGORITHM_SPECIFIC='--env AGENT57=1 -v $PWD/tmp:/code/tmp_Pong-v4'
elif [ "$ALGORITHM" == "dqn" ]; then
	ALGORITHM_SPECIFIC='--env DQN=1 -v $PWD/tmp:/code/tmp'
else
	1>&2 echo "Unknown algorithm '$ALGORITHM': must either be 'agent57' or 'dqn'!"
	exit 1
fi

echo "Training using algorithm $ALGORITHM"
REMAINING_VOLUME_MOUNTS='-v $PWD/repo/agent:/code/agent -v $PWD/repo/examples:/code/examples'
SSH_COMMAND="sudo docker run --rm --workdir /code $ALGORITHM_SPECIFIC $REMAINING_VOLUME_MOUNTS mkerschbaumer/openai-gym python3 examples/atari_pong.py"
echo "Executed SSH command: '$SSH_COMMAND'"
ssh "$TARGET" -- "$SSH_COMMAND" || exit

RESULTS_DIR=results
if [ ! -d "$RESULTS_DIR" ]; then
	echo "Creating local results directory"
	mkdir "$RESULTS_DIR" || exit
fi

RESULT_ZIP_FILE="$ALGORITHM.zip"
echo "Creating zip file '$RESULT_ZIP_FILE' on VM"
ssh "$TARGET" -- "zip -r $RESULT_ZIP_FILE \$(find tmp -type f -name '*.json')" || exit

echo "Downloading results from VM"
scp -r "$TARGET:$RESULT_ZIP_FILE" "$RESULTS_DIR" || exit

