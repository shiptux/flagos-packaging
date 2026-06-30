set +e
pip install -q sqlalchemy pyyaml 2>&1 | tail -1
export PYTHONPATH=/s/FlagAttention/src:/s/FlagBLAS/src:/s/FlagSparse/src:/s/FlagDNN/src:/s/FlagTensor/src
CLEAN='grep -avE UserWarning|warnings.warn|Overriding|registered at|dispatch key|operator:|self.m|previous kernel|new kernel|Warning.only|No.specialized|\[Note\]'
run(){ echo "===== $1 ====="; timeout 100 python -c "$2" 2>&1 | grep -avE 'UserWarning|warnings.warn|Overriding|registered at|dispatch key|operator:|self\.m|previous kernel|new kernel|Warning only|No specialized|\[Note\]' | tail -4; rc=${PIPESTATUS[0]}; [ "$rc" = 124 ] && echo "  -> HANG (780M 重kernel限制)" || echo "  -> exit=$rc"; }

run FlagTensor.add "
import torch
from flagtensor.ops.CUTENSOR_OP_ADD import add
a=torch.randn(4096,device='cuda'); b=torch.randn(4096,device='cuda')
c=add(a,b); torch.cuda.synchronize(); print('OK add', tuple(c.shape), round(float(c.sum()),1))"

run FlagAttention.flash "
import torch, flag_attn
q=torch.randn(1,4,256,64,device='cuda',dtype=torch.float16)
k=torch.randn_like(q); v=torch.randn_like(q)
o=flag_attn.flash_attention(q,k,v,causal=True); torch.cuda.synchronize(); print('OK flash', tuple(o.shape))"

run FlagBLAS.import "
import flag_blas, flag_blas.ops as ops
print('OK import; ops sample:', [x for x in dir(ops) if not x.startswith('_')][:6])"

run FlagDNN.import "
import flag_dnn
print('OK import flag_dnn')"

run FlagSparse.import "
import flagsparse
print('OK import flagsparse')"
echo "===== DONE ====="
