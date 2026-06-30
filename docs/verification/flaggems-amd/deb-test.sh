set +e
echo "=== 装 deb 声明的运行时缺口(容器 venv 里补 sqlalchemy)==="
pip install -q sqlalchemy 2>&1 | tail -1
echo "=== dpkg -i 安装 python3-flag-gems deb ==="
dpkg -i --force-depends /deb/python3-flag-gems_*.deb 2>&1 | grep -iE 'Unpacking|Setting up|flag-gems' | head
echo "--- deb 装了哪些文件(flag_gems 落点)---"
INSTDIR=$(dpkg -L python3-flag-gems 2>/dev/null | grep '/flag_gems/__init__.py$' | head -1 | xargs -r dirname | xargs -r dirname)
echo "INSTDIR=$INSTDIR"
echo
echo "=== [核心] 从 deb 安装位置 import(不是源码)+ 路径 + C 扩展 ==="
PYTHONPATH="$INSTDIR" python -c "
import flag_gems
print('flag_gems loaded from:', flag_gems.__file__)
print('FLAGGEMS_HAS_C_EXTENSION =', flag_gems.config.has_c_extension)
"
echo
echo "=== 在 780M 上跑 deb 装的 FlagGems 算子 ==="
PYTHONPATH="$INSTDIR" timeout 120 python -c "
import torch, flag_gems
a=torch.randn(1024,device='cuda'); b=torch.randn(1024,device='cuda')
with flag_gems.use_gems():
    c=a+b
torch.cuda.synchronize()
print('DEB_FLAGGEMS_ON_AMD_OK', c.device, round(float(c.sum()),2))
" 2>&1 | grep -avE 'UserWarning|warnings.warn|Overriding|registered at|dispatch key|operator:|self.m|previous kernel|new kernel|Warning only|No specialized' | tail -6
echo "=== DONE ==="
