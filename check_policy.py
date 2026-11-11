"""
check_policy.py —— 离线检查模型（不连机械臂）
把录好的数据喂给模型，比较"模型预测的动作"和"你当时真实做的动作"。

用法（先 conda activate lerobot，再进入这个文件夹）：
    python check_policy.py 模型名 数据集名
例子：
    python check_policy.py act_pick_ball_v2 yiming19/pick_ball_v2_clean
"""
import sys, time                       # sys：读取命令行参数；time：计时
from pathlib import Path
import torch
from lerobot.datasets.lerobot_dataset import LeRobotDataset        # 读取录好的数据集
from lerobot.policies.act.modeling_act import ACTPolicy            # ACT 模型
from lerobot.policies.factory import make_pre_post_processors      # 归一化/反归一化工具（和 rollout 用的是同一个）

MODEL_DIR = Path(__file__).parent / "models" / sys.argv[1]   # 第 1 个参数：模型名
REPO_ID = sys.argv[2]                                         # 第 2 个参数：数据集名
DEVICE = "mps"                                                # 和 eval.sh 一样，用 M1 的 GPU

policy = ACTPolicy.from_pretrained(MODEL_DIR)   # 加载模型权重
policy.config.device = DEVICE
policy.to(DEVICE).eval()                         # 放到 GPU 上，切换到推理模式
pre, post = make_pre_post_processors(            # 加载训练时保存的归一化参数
    policy_cfg=policy.config, pretrained_path=str(MODEL_DIR),
    preprocessor_overrides={"device_processor": {"device": DEVICE}})  # 训练时是 cuda，这里改成 mps

ds = LeRobotDataset(REPO_ID)                     # 读本地的数据集
for ep in [0, 10, 20, 30, 40]:                   # 抽 5 条录制，球在不同位置
    start = ds.meta.episodes[ep]["dataset_from_index"]   # 这条录制的第一帧是全局第几帧
    for t in [0, 90, 240]:                       # 每条看 3 个时刻：开头、3 秒、8 秒
        item = ds[start + t]                     # 取出这一帧：两路图片 + 关节角度 + 真实动作
        obs = {k: item[k] for k in policy.config.input_features}   # 只留模型需要的输入
        batch = pre(obs)                         # 归一化，加 batch 维度，放到 GPU
        t0 = time.time()
        with torch.no_grad():                    # 推理时不需要算梯度
            chunk = policy.predict_action_chunk(batch)   # 模型一次预测接下来 100 步的动作
        torch.mps.synchronize(); ms = (time.time() - t0) * 1000   # 等 GPU 算完再计时
        pred = post(chunk)[0]                    # 反归一化，得到真实的关节角度
        k = 30                                   # 比较 1 秒之后（第 30 步）
        real = ds[start + t + k]["action"]       # 你当时 1 秒后真实做的动作
        state = item["observation.state"]        # 当前关节角度
        print(f"ep{ep} t={t/30:.0f}s 推理{ms:.0f}ms | 当前 {state.numpy().round(0)} "
              f"| 1秒后真实 {real.numpy().round(0)} | 1秒后预测 {pred[k].numpy().round(0)}")
