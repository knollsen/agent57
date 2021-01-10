#!/usr/bin/env bash

function usage() {
	echo "$0 <VM instance IP> [ssh-key-file]"
	echo "The first parameter is required and the second one (ssh key file) is optional."
	echo "e.g. $0 123.456.789.123 ~/.ssh/id_ed25519"
	echo
	echo "The default username can be overridden by setting SSH_USERNAME"
}

# Display help if explicitly required or nothing is passed
if [[ "$1" == "--help" || -z "$1" ]]; then
	usage
	exit 0
fi

VM_IP=$1
SSH_KEY_FILE=$2

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
ssh "$TARGET" -- "sudo apt update && sudo apt install -y docker.io" || exit

echo "Downloading required docker image"
ssh "$TARGET" -- sudo docker pull mkerschbaumer/openai-gym || exit

echo "Training Agent57"
ssh "$TARGET" -- 'sudo docker run --rm --workdir /code --env AGENT57=1 -v $PWD/tmp:/code/tmp_Pong-v4 mkerschbaumer/openai-gym python3 examples/atari_pong.py'

RESULTS_DIR=results
if [ ! -d "$RESULTS_DIR" ]; then
	echo "Creating results directory"
	mkdir "$RESULTS_DIR" || exit
fi

echo "Downloading results from VM"
scp -r "$TARGET:tmp/*.json" "$RESULTS_DIR" || exit

