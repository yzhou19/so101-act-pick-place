# =====================================================================
#  config.sh —— SO-101 的硬件信息（只在这个文件里改）
#
#  这个文件不用直接运行。teleop.sh 和 record.sh 开头会先读取它，
#  拿到下面这些变量（端口、名字、相机编号），再拼成完整的 lerobot 命令。
#  以后换了 USB 口、换了相机，只改这里，脚本不用动。
# =====================================================================


# ---------- 1. 两只机械臂 ----------
# 端口：用 lerobot-find-port 找到的。端口名里带控制板的序列号，一般不会变。
# 名字（ID）：校准时起的名字。LeRobot 靠这个名字找到对应的校准文件，
#             所以每条命令都必须用同一个名字，否则会要求重新校准。

FOLLOWER_PORT=/dev/tty.usbmodem5C4C1240981   # 从动臂（跟着动的那只，插 12V 电源）
FOLLOWER_ID=my_awesome_follower_arm

LEADER_PORT=/dev/tty.usbmodem5C821109521     # 主动臂（你用手拿着动的那只）
LEADER_ID=my_awesome_leader_arm


# ---------- 2. 两个摄像头 ----------
# 编号：lerobot-find-cameras opencv 找到的。插拔或者 iPhone 靠近时编号偶尔会变，
#       如果发现画面对调了，重新运行 find-cameras 确认，再改这里。

TOP_CAM=0      # 顶部固定视角
WRIST_CAM=1    # 腕部（夹爪上）

# 下面这一行把两个相机的设置拼成 LeRobot 要的格式，一般不用改。
# 分辨率 640x480、每秒 30 帧。
# 注意：top 和 wrist 这两个名字会写进数据集，训练和真机测试都要用同样的名字，定了就别改。
CAMERAS="{ top: {type: opencv, index_or_path: $TOP_CAM, width: 640, height: 480, fps: 30}, wrist: {type: opencv, index_or_path: $WRIST_CAM, width: 640, height: 480, fps: 30} }"


# ---------- 3. Hugging Face 用户名 ----------
# 不用手填：下面这行会自动查出你登录的用户名。
# 前提：先在终端运行过一次 hf auth login（token 只在那一步粘贴，不要写进这个文件，
#       这个文件夹以后要传到 GitHub，写进来就公开了）。

HF_USER=$(python -c "from huggingface_hub import whoami; print(whoami()['name'])" 2>/dev/null)
