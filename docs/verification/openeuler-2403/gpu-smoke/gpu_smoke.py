"""Real-GPU smoke for FlagTree (triton fork) packaged for openEuler 24.03.

Runs a vector-add triton kernel on the actual device and checks the
result, then (best-effort) exercises a FlagAttention flash-attention op.
Requires an NVIDIA GPU + driver; torch provides the CUDA runtime.
"""
import torch
import triton
import triton.language as tl


@triton.jit
def add_kernel(x_ptr, y_ptr, out_ptr, n_elements, BLOCK_SIZE: tl.constexpr):
    pid = tl.program_id(axis=0)
    offsets = pid * BLOCK_SIZE + tl.arange(0, BLOCK_SIZE)
    mask = offsets < n_elements
    x = tl.load(x_ptr + offsets, mask=mask)
    y = tl.load(y_ptr + offsets, mask=mask)
    tl.store(out_ptr + offsets, x + y, mask=mask)


def main():
    assert torch.cuda.is_available(), "no CUDA device visible"
    n = 1 << 20
    x = torch.rand(n, device="cuda")
    y = torch.rand(n, device="cuda")
    out = torch.empty_like(x)
    grid = lambda meta: (triton.cdiv(n, meta["BLOCK_SIZE"]),)
    add_kernel[grid](x, y, out, n, BLOCK_SIZE=1024)
    torch.cuda.synchronize()
    assert torch.allclose(out, x + y), "vector-add result mismatch"
    print("triton vector-add on device: OK")

    try:
        import flag_attn
        q, k, v = (torch.randn(1, 2, 128, 64, device="cuda", dtype=torch.float16)
                   for _ in range(3))
        o = flag_attn.flash_attention(q, k, v)
        assert o.shape == q.shape
        print("flag_attn.flash_attention: OK")
    except Exception as exc:  # best-effort: don't fail the smoke on op-level issues
        print(f"flag_attn check skipped/failed (non-fatal): {exc}")

    print("GPU SMOKE PASS", torch.cuda.get_device_name(0))


if __name__ == "__main__":
    main()
