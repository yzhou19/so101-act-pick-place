#!/usr/bin/env bash
# =====================================================================
#  teleop.sh —— 遥操作：你动主动臂，从动臂跟着动
#
#  用法（先 conda activate lerobot，再进入这个文件夹）：
#     ./teleop.sh          带两路相机画面（会弹出 Rerun 窗口）
#     ./teleop.sh nocam    只动臂，不开相机（相机出问题时用）
#
#  停止：在终端按 Ctrl+C
# =====================================================================

# 遇到错误就立刻停下，不继续往下执行
set -e

# 读取 config.sh 里的端口、名字、相机设置
# （$(dirname "$0") 表示"这个脚本所在的文件夹"，这样在哪个目录运行都能找到 config.sh）
source "$(dirname "$0")/config.sh"


if [ "$1" = "nocam" ]; then
    # ---- 不开相机 ----
    lerobot-teleoperate \
        --robot.type=so101_follower \
        --robot.port="$FOLLOWER_PORT" \
        --robot.id="$FOLLOWER_ID" \
        --teleop.type=so101_leader \
        --teleop.port="$LEADER_PORT" \
        --teleop.id="$LEADER_ID"
else
    # ---- 开相机，并显示画面 ----
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
