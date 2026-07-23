"""AOT compile smoke for FlagTree (triton fork) on a GPU-less host.

Compiles a vector-add kernel to PTX for sm_80 without any NVIDIA
driver present, proving the full frontend -> MLIR -> LLVM -> PTX
chain of the packaged wheel works on this distro.
"""
import triton
import triton.language as tl
from triton.backends.compiler import GPUTarget


@triton.jit
def add_kernel(x_ptr, y_ptr, out_ptr, n_elements, BLOCK_SIZE: tl.constexpr):
    pid = tl.program_id(axis=0)
    offsets = pid * BLOCK_SIZE + tl.arange(0, BLOCK_SIZE)
    mask = offsets < n_elements
    x = tl.load(x_ptr + offsets, mask=mask)
    y = tl.load(y_ptr + offsets, mask=mask)
    tl.store(out_ptr + offsets, x + y, mask=mask)


def main():
    src = triton.compiler.ASTSource(
        fn=add_kernel,
        signature={"x_ptr": "*fp32", "y_ptr": "*fp32", "out_ptr": "*fp32",
                   "n_elements": "i32", "BLOCK_SIZE": "constexpr"},
        constexprs={"BLOCK_SIZE": 1024},
    )
    target = GPUTarget("cuda", 80, 32)
    compiled = triton.compile(src, target=target)
    stages = list(compiled.asm.keys())
    print("stages:", stages)
    ptx = compiled.asm["ptx"]
    assert ".visible .entry" in ptx, "no kernel entry in PTX"
    assert "add_kernel" in ptx, "kernel name missing in PTX"
    head = [l for l in ptx.splitlines() if l.startswith((".version", ".target"))]
    print("ptx header:", head)
    print("PTX bytes:", len(ptx))
    print("AOT SMOKE PASS")


if __name__ == "__main__":
    main()
