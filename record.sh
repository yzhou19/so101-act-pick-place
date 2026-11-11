#!/usr/bin/env bash
# =====================================================================
#  record.sh —— 采数据：一边遥操作，一边把动作和两路相机画面录下来
#
#  用法（先 conda activate lerobot，再进入这个文件夹）：
#     ./record.sh  数据集名  "任务描述"  录几条
#
#  例子：
#     ./record.sh  test_run   "Pick up the cube and place it in the box"  3
#     ./record.sh  pick_cube  "Pick up the cube and place it in the box"  50
#
#  录制时的按键：
#     →  （右方向键）提前结束当前这一条，进入下一条
#     ←  （左方向键）这一条不要了，重录
#     Esc           结束整个录制并保存
#
#  录好的数据存在：~/.cache/huggingface/lerobot/<你的用户名>/<数据集名>_<日期时间>/
#  默认只存在本地，不上传。
#
#  中途停了、想接着往同一个数据集里补录：
#     数据集名要写带日期时间的完整名字，最后加一个 resume，"录几条"填还要再录几条
#     ./record.sh  pick_cube_20261108_101500  "Pick up the cube and place it in the box"  20  resume
# =====================================================================

set -e
source "$(dirname "$0")/config.sh"


# ---------- 读取你在命令里写的三个参数 ----------
DATASET_NAME="$1"     # 第 1 个：数据集名，例如 pick_cube
TASK="$2"             # 第 2 个：任务描述（英文一句话，SmolVLA 训练时会用到）
NUM_EPISODES="$3"     # 第 3 个：录几条
MODE="$4"             # 第 4 个（可选）：写 resume 表示接着已有的数据集补录

# 没登录 Hugging Face 的话，拿不到用户名，提示先登录
if [ -z "$HF_USER" ]; then
    echo "还没登录 Hugging Face：请先运行 hf auth login"
    exit 1
fi

# 补录（resume）：打开 LeRobot 的 resume 选项，并告诉它数据集在电脑上的文件夹（--dataset.root），否则会报错
if [ "$MODE" = "resume" ]; then
    RESUME=true
    DATASET_FOLDER="$HOME/.cache/huggingface/lerobot/$HF_USER/$DATASET_NAME"
    if [ ! -d "$DATASET_FOLDER" ]; then
        echo "找不到数据集文件夹：$DATASET_FOLDER"
        echo "补录时数据集名要写带日期时间的完整名字，可以用 ls ~/.cache/huggingface/lerobot/$HF_USER/ 查看"
        exit 1
    fi
    ROOT_OPTION=(--dataset.root="$DATASET_FOLDER")
else
    RESUME=false
    ROOT_OPTION=()    # 新录时不需要，LeRobot 自己决定存在哪
fi

# 三个参数没写全，就提示用法并退出
if [ -z "$DATASET_NAME" ] || [ -z "$TASK" ] || [ -z "$NUM_EPISODES" ]; then
    echo "用法: ./record.sh 数据集名 \"任务描述\" 录几条"
    echo "例子: ./record.sh test_run \"Pick up the cube and place it in the box\" 3"
    exit 1
fi



# ---------- 每条的时长（秒），需要时改这里 ----------
EPISODE_SECONDS=20    # 每条最长录多久
RESET_SECONDS=10      # 两条之间留多久，让你把物体摆回去

# ---------- 录制时要不要弹出 Rerun 实时画面 ----------
# false = 不显示（推荐：MacBook Air 同时显示画面 + 压缩视频会忙不过来，出现 "running slower" 警告）
# true  = 显示（只在想确认相机画面时临时打开）
SHOW_DISPLAY=false


# ---------- 开始录制 ----------
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
