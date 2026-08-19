#!/usr/bin/env python3
"""Run isolated, result-checked GPU smokes for FlagOS Python components."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import time


ROOT = Path(os.environ.get("FLAGOS_A100_ROOT", "/root/flagos-a100-test"))
SOURCES = ROOT / "sources"
LOGS = ROOT / "logs"
RESULTS = ROOT / "results"
TESTS = {
    "flag-attention": {
        "paths": [SOURCES / "FlagAttention" / "src"],
        "code": r'''
import torch
import torch.nn.functional as F
import flag_attn

torch.manual_seed(7)
q = torch.randn((1, 2, 128, 64), device="cuda", dtype=torch.float16)
k = torch.randn_like(q)
v = torch.randn_like(q)
actual = flag_attn.flash_attention(q, k, v, causal=True)
expected = F.scaled_dot_product_attention(q, k, v, is_causal=True)
torch.cuda.synchronize()
torch.testing.assert_close(actual, expected, rtol=2e-2, atol=2e-2)
assert torch.isfinite(actual).all()
print("FLAG_ATTENTION_PASS", tuple(actual.shape), float((actual - expected).abs().max()))
''',
    },
    "flag-audio": {
        "paths": [SOURCES / "FlagAudio" / "src"],
        "code": r'''
import torch
from flag_audio import gain

x = torch.linspace(-1.0, 1.0, 4096, device="cuda")
max_diff = 0.0
for gain_db in (0.0, 1.0, -6.0, 6.0):
    actual = gain(x, gain_db=gain_db)
    expected = x * (10.0 ** (gain_db / 20.0))
    torch.cuda.synchronize()
    torch.testing.assert_close(actual, expected, rtol=1e-5, atol=1e-6)
    max_diff = max(max_diff, float((actual - expected).abs().max()))
print("FLAG_AUDIO_PASS", tuple(actual.shape), max_diff)
''',
    },
    "flag-blas": {
        "paths": [SOURCES / "FlagBLAS" / "src"],
        "code": r'''
import torch
import flag_blas

torch.manual_seed(11)
n = 8192
x = torch.randn(n, device="cuda", dtype=torch.float32)
y = torch.randn(n, device="cuda", dtype=torch.float32)
expected = 1.5 * x + y
flag_blas.saxpy(n, 1.5, x, 1, y, 1)
torch.cuda.synchronize()
torch.testing.assert_close(y, expected, rtol=1e-5, atol=1e-5)
print("FLAG_BLAS_PASS", flag_blas.vendor_name, float((y - expected).abs().max()))
''',
    },
    "flag-dnn": {
        "paths": [SOURCES / "FlagDNN" / "src"],
        "code": r'''
import torch
import flag_dnn

torch.manual_seed(13)
x = torch.randn((128, 256), device="cuda", dtype=torch.float32)
actual = flag_dnn.relu(x)
expected = torch.relu(x)
torch.cuda.synchronize()
torch.testing.assert_close(actual, expected, rtol=0, atol=0)
print("FLAG_DNN_PASS", flag_dnn.vendor_name, int(torch.count_nonzero(actual)))
''',
    },
    "flag-gems": {
        "paths": [SOURCES / "FlagGems" / "src"],
        "code": r'''
import torch
import flag_gems

torch.manual_seed(17)
x = torch.randn(16384, device="cuda", dtype=torch.float32)
y = torch.randn_like(x)
expected = x + y
actual = flag_gems.add(x, y)
torch.cuda.synchronize()
torch.testing.assert_close(actual, expected, rtol=1e-5, atol=1e-5)
print("FLAG_GEMS_PASS", flag_gems.vendor_name, float((actual - expected).abs().max()))
''',
    },
    "flag-quantum": {
        "paths": [SOURCES / "FlagQuantum"],
        "code": r'''
import torch
import flagquantum as fq

qdev = fq.DistributedQuantumDevice(n_wires=3, bsz=2, device="cuda", world_sz=1)
fq.h(qdev, wires=[0])
fq.cx(qdev, wires=[0, 1])
expectations = fq.measure_allZ(qdev)
torch.cuda.synchronize()
assert qdev.states.device.type == "cuda"
assert expectations.shape == (2, 3)
expected = torch.tensor([[0.0, 0.0, 1.0], [0.0, 0.0, 1.0]], device="cuda")
torch.testing.assert_close(expectations, expected, rtol=1e-5, atol=1e-5)
print("FLAG_QUANTUM_PASS", tuple(expectations.shape), expectations.tolist())
''',
    },
    "flag-scale": {
        "paths": [SOURCES / "FlagScale"],
        "code": r'''
import importlib.util
from pathlib import Path
import torch

path = Path("/root/flagos-a100-test/sources/FlagScale/flagscale/train/megatron/training/spiky_loss.py")
spec = importlib.util.spec_from_file_location("flagscale_spiky_loss", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
detector = module.SpikyLossDetector(threshold=0.2, loss=torch.tensor(10.0, device="cuda"))
normal = detector.is_spkiy_loss(torch.tensor(10.5, device="cuda"))
spike = detector.is_spkiy_loss(torch.tensor(14.0, device="cuda"))
torch.cuda.synchronize()
assert not bool(normal)
assert bool(spike)
print("FLAG_SCALE_PASS", normal, spike)
''',
    },
    "flag-sparse": {
        "paths": [SOURCES / "FlagSparse" / "src"],
        "code": r'''
import torch
from flagsparse import flagsparse_gather

torch.manual_seed(19)
dense = torch.randn(4096, device="cuda", dtype=torch.float32)
indices = torch.randperm(dense.numel(), device="cuda")[:1024].to(torch.int32)
actual = flagsparse_gather(dense, indices)
expected = dense.index_select(0, indices.to(torch.int64))
torch.cuda.synchronize()
torch.testing.assert_close(actual, expected, rtol=0, atol=0)
print("FLAG_SPARSE_PASS", tuple(actual.shape), float(actual.sum()))
''',
    },
    "flag-tensor": {
        "paths": [SOURCES / "FlagTensor" / "src"],
        "code": r'''
import torch
from flagtensor.ops.CUTENSOR_OP_ADD import add

torch.manual_seed(23)
x = torch.randn((128, 128), device="cuda", dtype=torch.float32)
y = torch.randn_like(x)
actual = add(x, y)
expected = x + y
torch.cuda.synchronize()
torch.testing.assert_close(actual, expected, rtol=1e-5, atol=1e-5)
print("FLAG_TENSOR_PASS", tuple(actual.shape), float((actual - expected).abs().max()))
''',
    },
}


def run_test(name: str, config: dict[str, object]) -> dict[str, object]:
    env = os.environ.copy()
    paths = [str(path) for path in config["paths"]]
    existing = env.get("PYTHONPATH")
    if existing:
        paths.append(existing)
    env.update(
        {
            "PYTHONPATH": os.pathsep.join(paths),
            "GEMS_VENDOR": "nvidia",
            "TRITON_CACHE_DIR": str(ROOT / "work" / "triton-cache" / name),
        }
    )
    started = time.monotonic()
    try:
        completed = subprocess.run(
            [sys.executable, "-c", str(config["code"])],
            check=False,
            capture_output=True,
            env=env,
            text=True,
            timeout=600,
        )
        returncode = completed.returncode
        output = completed.stdout + completed.stderr
        status = "PASS" if returncode == 0 else "FAIL"
    except subprocess.TimeoutExpired as exc:
        returncode = 124
        output = (exc.stdout or "") + (exc.stderr or "")
        status = "TIMEOUT"

    duration = round(time.monotonic() - started, 3)
    log_path = LOGS / f"python-{name}.log"
    log_path.write_text(output, encoding="utf-8")
    print(f"{name:16} {status:7} rc={returncode:<3} {duration:8.3f}s")
    if output:
        for line in output.rstrip().splitlines()[-4:]:
            print(f"  {line}")
    return {
        "component": name,
        "status": status,
        "returncode": returncode,
        "duration_seconds": duration,
        "log": str(log_path),
    }


def main() -> int:
    LOGS.mkdir(parents=True, exist_ok=True)
    RESULTS.mkdir(parents=True, exist_ok=True)
    results = [run_test(name, config) for name, config in TESTS.items()]
    result_path = RESULTS / "python-smokes.json"
    result_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
    passed = sum(item["status"] == "PASS" for item in results)
    print(f"PYTHON_SMOKES {passed}/{len(results)} PASS")
    print(result_path)
    return 0 if passed == len(results) else 1


if __name__ == "__main__":
    raise SystemExit(main())
