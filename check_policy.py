"""Offline sanity check: compare a policy's predicted actions with the recorded ones.

Usage: python check_policy.py act_pick_ball_v2 yiming19/pick_ball_v2_clean
"""
import sys
import time
from pathlib import Path

import torch
from lerobot.datasets.lerobot_dataset import LeRobotDataset
from lerobot.policies.act.modeling_act import ACTPolicy
from lerobot.policies.factory import make_pre_post_processors

MODEL_DIR = Path(__file__).parent / "models" / sys.argv[1]
REPO_ID = sys.argv[2]
DEVICE = "mps"

policy = ACTPolicy.from_pretrained(MODEL_DIR)
policy.config.device = DEVICE
policy.to(DEVICE).eval()
pre, post = make_pre_post_processors(
    policy_cfg=policy.config, pretrained_path=str(MODEL_DIR),
    preprocessor_overrides={"device_processor": {"device": DEVICE}})  # trained on cuda

ds = LeRobotDataset(REPO_ID)
for ep in [0, 10, 20, 30, 40]:
    start = ds.meta.episodes[ep]["dataset_from_index"]
    for t in [0, 90, 240]:  # 0 s, 3 s, 8 s into the episode
        item = ds[start + t]
        obs = {k: item[k] for k in policy.config.input_features}
        batch = pre(obs)
        t0 = time.time()
        with torch.no_grad():
            chunk = policy.predict_action_chunk(batch)
        torch.mps.synchronize()
        ms = (time.time() - t0) * 1000
        pred = post(chunk)[0]
        k = 30  # compare 1 s ahead
        real = ds[start + t + k]["action"]
        state = item["observation.state"]
        print(f"ep{ep} t={t/30:.0f}s {ms:.0f}ms | state {state.numpy().round(0)} "
              f"| real +1s {real.numpy().round(0)} | pred +1s {pred[k].numpy().round(0)}")
