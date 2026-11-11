"""
make_media.py —— 从 rollout 录像里剪出 README 用的 GIF 和邮件用的 MP4
用法（conda activate lerobot 之后）：python make_media.py
输出：media/act_demo.gif 和 media/act_trials.mp4（都是俯视 + 腕部并排，原速）
"""
import glob
from pathlib import Path
import av                                   # 读写视频（lerobot 自带）
import pandas as pd                         # 读 episode 的元数据（每条从视频第几秒开始）
from PIL import Image, ImageDraw, ImageFont # 拼画面、写字、做 GIF

ROLLOUT = Path.home() / ".cache/huggingface/lerobot/yiming19/rollout_act_pick_ball_v2_20261111_124215"
OUT = Path(__file__).parent / "media"       # 输出放在 so101/media/
FPS = 30                                    # 录像是 30 帧/秒
TRIM_END = 30                               # 整条片段去掉最后 1 秒（球已经进碗；腕部相机这时可能拍到桌边的人）

# 要剪的片段：(episode 编号, 截到第几帧为止（None=整条）, 标签)。必须按 episode 顺序排，因为视频是从头往后读一遍
GIF_CLIPS = [(4, None, "trial 5/20")]       # 原速 + 两路画面文件较大，GIF 只放 1 次成功
MP4_CLIPS = [(3, None, "SUCCESS"), (6, 420, "FAILURE (missed grasp)"), (8, None, "SUCCESS"),
             (10, None, "SUCCESS"), (12, None, "SUCCESS")]

# ---- 1. 算出每条 episode 在视频文件里是第几帧到第几帧 ----
meta = pd.concat(pd.read_parquet(f) for f in sorted(glob.glob(str(ROLLOUT / "meta/episodes/*/*.parquet"))))
start = {int(r.episode_index): round(r["videos/observation.images.top/from_timestamp"] * FPS) for _, r in meta.iterrows()}
length = {int(r.episode_index): int(r.length) for _, r in meta.iterrows()}

def wanted(clips, step):
    """返回 {视频里的帧号: (episode, 标签)}；step=6 表示每 6 帧取 1 帧"""
    out = {}
    for ep, stop, label in clips:
        n = stop or length[ep] - TRIM_END               # 这一段要多少帧
        for k in range(0, n, step):
            out[start[ep] + k] = (ep, label)
    return out

def banner(img, text, size=22):
    """在画面上方加一条黑底白字；size 是字号"""
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)   # Mac 自带字体
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, img.width, size + 12), fill="black")
    d.text((8, 5), text, fill="white", font=font)
    return img

OUT.mkdir(exist_ok=True)
top_file = ROLLOUT / "videos/observation.images.top/chunk-000/file-000.mp4"
wrist_file = ROLLOUT / "videos/observation.images.wrist/chunk-000/file-000.mp4"

# ---- 2. GIF：俯视 + 腕部并排；10 帧/秒显示，每 3 帧取 1 帧 = 原速 ----
gif_want = wanted(GIF_CLIPS, step=3)
frames = []
with av.open(str(top_file)) as ct, av.open(str(wrist_file)) as cw:
    for i, (ft, fw) in enumerate(zip(ct.decode(video=0), cw.decode(video=0))):   # 两个摄像头同步往后读
        if i in gif_want:
            ep, label = gif_want[i]
            img = Image.new("RGB", (640, 240))
            img.paste(ft.to_image().resize((320, 240)), (0, 0))     # 左：俯视（缩小，控制 GIF 大小）
            img.paste(fw.to_image().resize((320, 240)), (320, 0))   # 右：腕部
            frames.append(banner(img, f"ACT policy on SO-101, autonomous, real-time  |  {label}", size=15))
        if i > max(gif_want):                           # 需要的帧都拿到了就停
            break
frames[0].save(OUT / "act_demo.gif", save_all=True, append_images=frames[1:],
               duration=100, loop=0, optimize=True)     # 每帧 100 毫秒，无限循环

# ---- 3. MP4：俯视 + 腕部并排；30 帧/秒输出，每帧都取 = 原速 ----
mp4_want = wanted(MP4_CLIPS, step=1)
with av.open(str(top_file)) as ct, av.open(str(wrist_file)) as cw, \
     av.open(str(OUT / "act_trials.mp4"), "w") as out:
    vs = out.add_stream("libx264", rate=FPS)            # H.264，QuickTime 和邮件都能直接播放
    vs.width, vs.height, vs.pix_fmt = 1280, 480, "yuv420p"
    vs.options = {"crf": "23"}                          # 画质参数：数字越小越清晰、文件越大
    for i, (ft, fw) in enumerate(zip(ct.decode(video=0), cw.decode(video=0))):   # 两个摄像头同步往后读
        if i in mp4_want:
            ep, label = mp4_want[i]
            img = Image.new("RGB", (1280, 480))
            img.paste(ft.to_image(), (0, 0))            # 左边：俯视
            img.paste(fw.to_image(), (640, 0))          # 右边：腕部
            banner(img, f"ACT on SO-101  |  trial {ep + 1}/20: {label}  |  14/20 overall  |  real-time")
            for pkt in vs.encode(av.VideoFrame.from_image(img)):   # 压缩成 H.264 写进文件
                out.mux(pkt)
        if i > max(mp4_want):
            break
    for pkt in vs.encode():                             # 把编码器里剩下的帧写完
        out.mux(pkt)

for f in sorted(OUT.iterdir()):
    print(f"{f.name}: {f.stat().st_size / 1e6:.1f} MB")
