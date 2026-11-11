#!/usr/bin/env bash
# Record teleoperated demonstrations.
# Usage: ./record.sh <dataset_name> "<task>" <num_episodes> [resume]
#   e.g. ./record.sh pick_ball "Pick up the ball and put it in the bowl" 50
# Keys: -> end episode early, <- re-record episode, Esc stop.
# To add episodes to an existing dataset, pass its full timestamped name and `resume`.
set -e
source "$(dirname "$0")/config.sh"

DATASET_NAME="$1"
TASK="$2"
NUM_EPISODES="$3"
MODE="$4"

if [ -z "$HF_USER" ]; then
    echo "Not logged in to Hugging Face. Run: hf auth login"
    exit 1
fi

if [ "$MODE" = "resume" ]; then
    RESUME=true
    DATASET_FOLDER="$HOME/.cache/huggingface/lerobot/$HF_USER/$DATASET_NAME"
    if [ ! -d "$DATASET_FOLDER" ]; then
        echo "Dataset not found: $DATASET_FOLDER"
        exit 1
    fi
    ROOT_OPTION=(--dataset.root="$DATASET_FOLDER")
else
    RESUME=false
    ROOT_OPTION=()
fi

if [ -z "$DATASET_NAME" ] || [ -z "$TASK" ] || [ -z "$NUM_EPISODES" ]; then
    echo "Usage: ./record.sh <dataset_name> \"<task>\" <num_episodes> [resume]"
    exit 1
fi

EPISODE_SECONDS=20
RESET_SECONDS=10
SHOW_DISPLAY=false   # live view slows recording on the M1 Air

lerobot-record \
    --robot.type=so101_follower \
    --robot.port="$FOLLOWER_PORT" \
    --robot.id="$FOLLOWER_ID" \
    --robot.cameras="$CAMERAS" \
    --teleop.type=so101_leader \
    --teleop.port="$LEADER_PORT" \
    --teleop.id="$LEADER_ID" \
    --display_data="$SHOW_DISPLAY" \
    --dataset.repo_id="$HF_USER/$DATASET_NAME" \
    --dataset.single_task="$TASK" \
    --dataset.num_episodes="$NUM_EPISODES" \
    --dataset.episode_time_s="$EPISODE_SECONDS" \
    --dataset.reset_time_s="$RESET_SECONDS" \
    --dataset.push_to_hub=false \
    --dataset.streaming_encoding=true \
    --dataset.encoder_threads=2 \
    --resume="$RESUME" \
    "${ROOT_OPTION[@]}"
