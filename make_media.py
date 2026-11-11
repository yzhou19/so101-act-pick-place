"""Build the README GIF and the trial MP4 from a recorded evaluation (top and wrist views side by side, real-time).

Usage: python make_media.py
"""
import glob
from pathlib import Path

import av
import pandas as pd
from PIL import Image, ImageDraw, ImageFont

ROLLOUT = Path.home() / ".cache/huggingface/lerobot/yiming19/rollout_act_pick_ball_v2_20261111_124215"
OUT = Path(__file__).parent / "media"
FPS = 30
TRIM_END = 30  # drop the last second of each trial

# (episode, last frame or None for the whole trial, label), in episode order
GIF_CLIPS = [(4, None, "trial 5/20")]
MP4_CLIPS = [(3, None, "SUCCESS"), (6, 420, "FAILURE (missed grasp)"), (8, None, "SUCCESS"),
             (10, None, "SUCCESS"), (12, None, "SUCCESS")]

meta = pd.concat(pd.read_parquet(f) for f in sorted(glob.glob(str(ROLLOUT / "meta/episodes/*/*.parquet"))))
start = {int(r.episode_index): round(r["videos/observation.images.top/from_timestamp"] * FPS) for _, r in meta.iterrows()}
length = {int(r.episode_index): int(r.length) for _, r in meta.iterrows()}


def wanted(clips, step):
    """Map video frame index -> (episode, label), keeping every `step`-th frame."""
    out = {}
    for ep, stop, label in clips:
        n = stop or length[ep] - TRIM_END
        for k in range(0, n, step):
            out[start[ep] + k] = (ep, label)
    return out


def banner(img, text, size=22):
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size)
    d = ImageDraw.Draw(img)
    d.rectangle((0, 0, img.width, size + 12), fill="black")
    d.text((8, 5), text, fill="white", font=font)
    return img


OUT.mkdir(exist_ok=True)
top_file = ROLLOUT / "videos/observation.images.top/chunk-000/file-000.mp4"
wrist_file = ROLLOUT / "videos/observation.images.wrist/chunk-000/file-000.mp4"

# GIF: 10 fps, every 3rd frame = real-time
gif_want = wanted(GIF_CLIPS, step=3)
frames = []
with av.open(str(top_file)) as ct, av.open(str(wrist_file)) as cw:
    for i, (ft, fw) in enumerate(zip(ct.decode(video=0), cw.decode(video=0))):
        if i in gif_want:
            ep, label = gif_want[i]
            img = Image.new("RGB", (640, 240))
            img.paste(ft.to_image().resize((320, 240)), (0, 0))
            img.paste(fw.to_image().resize((320, 240)), (320, 0))
            frames.append(banner(img, f"ACT policy on SO-101, autonomous, real-time  |  {label}", size=15))
        if i > max(gif_want):
            break
frames[0].save(OUT / "act_demo.gif", save_all=True, append_images=frames[1:],
               duration=100, loop=0, optimize=True)

# MP4: 30 fps, H.264
mp4_want = wanted(MP4_CLIPS, step=1)
with av.open(str(top_file)) as ct, av.open(str(wrist_file)) as cw, \
     av.open(str(OUT / "act_trials.mp4"), "w") as out:
    vs = out.add_stream("libx264", rate=FPS)
    vs.width, vs.height, vs.pix_fmt = 1280, 480, "yuv420p"
    vs.options = {"crf": "23"}
    for i, (ft, fw) in enumerate(zip(ct.decode(video=0), cw.decode(video=0))):
        if i in mp4_want:
            ep, label = mp4_want[i]
            img = Image.new("RGB", (1280, 480))
            img.paste(ft.to_image(), (0, 0))
            img.paste(fw.to_image(), (640, 0))
            banner(img, f"ACT on SO-101  |  trial {ep + 1}/20: {label}  |  14/20 overall  |  real-time")
            for pkt in vs.encode(av.VideoFrame.from_image(img)):
                out.mux(pkt)
        if i > max(mp4_want):
            break
    for pkt in vs.encode():
        out.mux(pkt)

for f in sorted(OUT.iterdir()):
    print(f"{f.name}: {f.stat().st_size / 1e6:.1f} MB")
