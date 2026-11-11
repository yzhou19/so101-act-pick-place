#!/usr/bin/env bash
# Teleoperate the follower arm with the leader arm.
# Usage: ./teleop.sh          # with camera view (Rerun)
#        ./teleop.sh nocam    # arms only
set -e
source "$(dirname "$0")/config.sh"

if [ "$1" = "nocam" ]; then
    lerobot-teleoperate \
        --robot.type=so101_follower \
        --robot.port="$FOLLOWER_PORT" \
        --robot.id="$FOLLOWER_ID" \
        --teleop.type=so101_leader \
        --teleop.port="$LEADER_PORT" \
        --teleop.id="$LEADER_ID"
else
    lerobot-teleoperate \
        --robot.type=so101_follower \
        --robot.port="$FOLLOWER_PORT" \
        --robot.id="$FOLLOWER_ID" \
        --robot.cameras="$CAMERAS" \
        --teleop.type=so101_leader \
        --teleop.port="$LEADER_PORT" \
        --teleop.id="$LEADER_ID" \
        --display_data=true
fi
