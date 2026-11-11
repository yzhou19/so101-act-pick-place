# Hardware settings, sourced by the other scripts.

# Ports from `lerobot-find-port`. IDs must match the names used at calibration.
FOLLOWER_PORT=/dev/tty.usbmodem5C4C1240981
FOLLOWER_ID=my_awesome_follower_arm
LEADER_PORT=/dev/tty.usbmodem5C821109521
LEADER_ID=my_awesome_leader_arm

# Indices from `lerobot-find-cameras opencv`; they can swap after replugging.
TOP_CAM=0
WRIST_CAM=1

# Camera names (top, wrist) are stored in the dataset and must stay the same for training and eval.
CAMERAS="{ top: {type: opencv, index_or_path: $TOP_CAM, width: 640, height: 480, fps: 30}, wrist: {type: opencv, index_or_path: $WRIST_CAM, width: 640, height: 480, fps: 30} }"

# Requires `hf auth login` once.
HF_USER=$(python -c "from huggingface_hub import whoami; print(whoami()['name'])" 2>/dev/null)
