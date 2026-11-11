#!/usr/bin/env bash
# =====================================================================
#  eval.sh —— 真机测试：让训练好的模型自己控制从动臂
#
#  用法（先 conda activate lerobot，再进入这个文件夹）：
#     ./eval.sh  模型名  try          试跑 60 秒，不录像（先确认模型能动、方向对）
#     ./eval.sh  模型名  录几次        正式评测，每次都录下来（例如 20）
#     ./eval.sh  模型名  录几次  步数  可选：预测一次后执行多少步（例如 50）
#
#  例子：
#     ./eval.sh  act_so101_pick_ball  try
#     ./eval.sh  act_so101_pick_ball  20
#  两种模式都会打开 Rerun 窗口，实时显示 top 和 wrist 相机画面。
#
#  模型放在：~/Projects/so101/models/<模型名>/（里面有 model.safetensors、config.json 等）
#
#  正式评测时的流程（每次）：
#     1. 模型控制从动臂做 EPISODE_SECONDS 秒；做完了可以按 → 提前结束这次
#     2. 进入复位时间：你用主动臂把从动臂带回起始姿态，把球摆到新位置
#     3. 自动开始下一次
#  按键：→ 提前结束这次   ← 这次不算、重来   Esc 结束全部
#  急停：Ctrl+C，或者直接关掉从动臂的 12V 电源
#
#  成功/失败要自己记（建议同时记下球的位置和失败原因），录像存在：
#     ~/.cache/huggingface/lerobot/<你的用户名>/rollout_<模型名>_<日期时间>/
# =====================================================================

set -e
source "$(dirname "$0")/config.sh"

MODEL_NAME="$1"
MODE="$2"
TASK="Pick up the ball and put it in the bowl"   # 必须和采数据时的任务描述一模一样
MODEL_DIR="$(cd "$(dirname "$0")" && pwd)/models/$MODEL_NAME"

if [ -z "$MODEL_NAME" ] || [ -z "$MODE" ]; then
    echo "用法: ./eval.sh 模型名 try   或   ./eval.sh 模型名 录几次"
    exit 1
fi
if [ ! -f "$MODEL_DIR/config.json" ]; then
    echo "找不到模型：$MODEL_DIR/config.json"
    exit 1
fi

# ---------- 每次的时长（秒），需要时改这里 ----------
EPISODE_SECONDS=20    # 模型每次最多做多久（和采数据时一样）
RESET_SECONDS=10      # 两次之间留多久，让你复位、摆球
ACTION_STEPS="${3:-}" # 可选第 3 个参数：预测一次后执行多少步；不写就用模型训练时的设置（ACT 100，SmolVLA 50）

# 模型在服务器上用 cuda 训练，Mac 上要改用 mps（Apple 芯片的 GPU）
DEVICE=mps

# ---------- 按需要加的额外参数 ----------
EXTRA_ARGS=()                                    # 先放一个空列表
if [ -n "$ACTION_STEPS" ]; then                  # 只有你指定了步数……
    EXTRA_ARGS+=(--policy.n_action_steps="$ACTION_STEPS")   # ……才覆盖模型默认值
fi
if grep -q '"type": "smolvla"' "$MODEL_DIR/config.json"; then   # 是 SmolVLA 吗？
    # 训练时摄像头改过名（top→camera1，wrist→camera2），评测时要用同样的改名
    EXTRA_ARGS+=(--rename_map='{"observation.images.top": "observation.images.camera1", "observation.images.wrist": "observation.images.camera2"}')
fi

if [ "$MODE" = "try" ]; then
    # ---- 试跑：不录像，跑 60 秒 ----
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
    # ---- 正式评测：录 N 次，复位时用主动臂把从动臂带回起点 ----
    if [ -z "$HF_USER" ]; then
        echo "还没登录 Hugging Face：请先运行 hf auth login"
        exit 1
    fi
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
