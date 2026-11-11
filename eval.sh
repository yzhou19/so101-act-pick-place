#!/usr/bin/env bash
# Run a trained policy on the robot.
# Usage: ./eval.sh <model> try                     # 60 s test, not recorded
#        ./eval.sh <model> <N> [action_steps]      # N recorded trials
# Models live in models/<model>/. During resets, use the leader arm to bring the follower back.
# Keys: -> end trial early, <- redo trial, Esc stop.
set -e
source "$(dirname "$0")/config.sh"

MODEL_NAME="$1"
MODE="$2"
TASK="Pick up the ball and put it in the bowl"   # must match the training task string
MODEL_DIR="$(cd "$(dirname "$0")" && pwd)/models/$MODEL_NAME"

if [ -z "$MODEL_NAME" ] || [ -z "$MODE" ]; then
    echo "Usage: ./eval.sh <model> try | ./eval.sh <model> <N> [action_steps]"
    exit 1
fi
if [ ! -f "$MODEL_DIR/config.json" ]; then
    echo "Model not found: $MODEL_DIR/config.json"
    exit 1
fi

EPISODE_SECONDS=20
RESET_SECONDS=10
ACTION_STEPS="${3:-}"   # steps executed per predicted chunk; default is the model's own setting
DEVICE=mps

EXTRA_ARGS=()
if [ -n "$ACTION_STEPS" ]; then
    EXTRA_ARGS+=(--policy.n_action_steps="$ACTION_STEPS")
fi
# SmolVLA was trained with cameras renamed to camera1/camera2.
if grep -q '"type": "smolvla"' "$MODEL_DIR/config.json"; then
    EXTRA_ARGS+=(--rename_map='{"observation.images.top": "observation.images.camera1", "observation.images.wrist": "observation.images.camera2"}')
fi

if [ "$MODE" = "try" ]; then
    lerobot-rollout \
        --strategy.type=base \
        --policy.path="$MODEL_DIR" \
        --device="$DEVICE" \
        --display_data=true \
        --robot.type=so101_follower \
        --robot.port="$FOLLOWER_PORT" \
        --robot.id="$FOLLOWER_ID" \
        --robot.cameras="$CAMERAS" \
        --task="$TASK" \
        "${EXTRA_ARGS[@]}" \
        --duration=60
else
    if [ -z "$HF_USER" ]; then
        echo "Not logged in to Hugging Face. Run: hf auth login"
        exit 1
    fi
    # Hardware H.264 encoding while recording keeps the gap between trials short.
    lerobot-rollout \
        --strategy.type=episodic \
        --policy.path="$MODEL_DIR" \
        "${EXTRA_ARGS[@]}" \
        --device="$DEVICE" \
        --display_data=true \
        --robot.type=so101_follower \
        --robot.port="$FOLLOWER_PORT" \
        --robot.id="$FOLLOWER_ID" \
        --robot.cameras="$CAMERAS" \
        --teleop.type=so101_leader \
        --teleop.port="$LEADER_PORT" \
        --teleop.id="$LEADER_ID" \
        --dataset.repo_id="$HF_USER/rollout_$MODEL_NAME" \
        --dataset.single_task="$TASK" \
        --dataset.num_episodes="$MODE" \
        --dataset.episode_time_s="$EPISODE_SECONDS" \
        --dataset.reset_time_s="$RESET_SECONDS" \
        --dataset.streaming_encoding=true \
        --dataset.rgb_encoder.vcodec=h264_videotoolbox \
        --dataset.push_to_hub=false
fi
