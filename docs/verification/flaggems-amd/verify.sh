#!/usr/bin/env bash
# Runs INSIDE the rocm/pytorch container (see run.sh). Confirms FlagGems
# runs on an AMD GPU via the pure-Python / triton-rocm path, and that it
# does NOT use libtriton_jit (has_c_extension == False).
set +e

# FlagGems imports sqlalchemy (operator-cache persistence) — the base
# image doesn't ship it. (This is also a dependency the python3-flag-gems
# deb must declare.)
pip install -q sqlalchemy 2>&1 | tail -1
export PYTHONPATH=${FLAGGEMS_SRC:-/FlagGems}/src

echo "=========== [1] rocm-smi: GPU visible? ==========="
rocm-smi --showproductname 2>/dev/null || rocm-smi 2>/dev/null || echo "(no rocm-smi output)"

echo "=========== [2] torch-ROCm sees the GPU? ==========="
python -c "import torch; print('torch', torch.__version__); print('cuda_avail', torch.cuda.is_available()); print('device', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NONE')"

echo "=========== [3] triton ==========="
python -c "import triton; print('triton', triton.__version__)" 2>&1 | head -1

echo "=========== [4] FlagGems path (core check) ==========="
python -c "import flag_gems; print('FLAGGEMS_HAS_C_EXTENSION =', flag_gems.config.has_c_extension)" 2>&1 | tail -3

echo "=========== [5] run a small FlagGems op on the GPU ==========="
timeout 120 python -c "
import torch, flag_gems
a=torch.randn(1024, device='cuda'); b=torch.randn(1024, device='cuda')
with flag_gems.use_gems():
    c=a+b
torch.cuda.synchronize()
print('FLAGGEMS_ADD_OK', c.device, round(float(c.sum()),2))
" 2>&1 | grep -avE 'UserWarning|warnings.warn|Overriding|registered at|dispatch key|operator:|self.m|previous kernel|new kernel|Warning only|No specialized' | tail -6
echo "(exit $? — 124 = kernel hang/timeout)"
echo "=========== DONE ==========="
