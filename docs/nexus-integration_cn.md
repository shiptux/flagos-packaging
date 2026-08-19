# FlagOS 包发布 Nexus 链路:现状、问题与决策请求

日期:2026-06-10

> **进展(2026-06-10/11 维护者反馈)**:方案已定——"一个工作流,
> 一个密钥":上传逻辑以 reusable workflow 形式放在
> `flagos-ai/build-infra` 仓库,各组件仓库只放一份轻量 caller 引用;
> org 级别只配一个 secret `NEXUS_TOKEN`(`用户:token` 格式,直接给
> `curl -u` 用),仓库 URL 不属机密、硬编码在 workflow 内。上传命令
> 按 Sonatype 各格式标准:deb 用 POST --data-binary 到 apt 仓根路径
> (Nexus 自动归档到 pool/),rpm 用 PUT --upload-file 到文件名路径。
> 可选 secret `NEXUS_CA_CERT` 预留内部 CA 场景。模板见
> flagos-packaging `templates/build-infra/upload-nexus.yml` 与
> `templates/upload-nexus-caller.yml`。下文第 3 节的方案对比保留作
> 为决策背景。

## 一句话结论

**CI → Nexus 的自动推送链路从未真正跑通过。** 当前 Nexus 上仅有的 FlagOS 包是手动上传的。修通需要管理员配置 secret,以及一个推送方案的决策,详见下文。

## 1. Nexus 服务端现状

服务地址:`https://resource.flagos.net`

仓库分两类:

- **FlagOS 发布目标仓**(3 个):`flagos-apt-hosted` / `flagos-yum-hosted` / `flagos-pypi-hosted`,用于存放 FlagOS 自有的 deb / rpm / wheel
- **厂商 SDK 镜像仓**(其余 `flagos-<格式>-<厂商>` 命名的仓):存放各厂商 SDK 包(如 iluvatar 的 PyPI 仓内有 50 个 `+corex.4.4.0` 后缀的包),不是 FlagOS 的发布目标
  - 如果这个理解有误请指正,它影响后面所有上传配置的指向

发布目标仓的当前内容:

| 仓库 | 内容 | 来源 |
|---|---|---|
| flagos-apt-hosted | libtriton-jit / libtriton-jit-dev 0.1.0-1 两个 deb | 2026-02-27 手动上传(时间与任何 CI run 都对不上,上传来源不是 GitHub runner) |
| flagos-yum-hosted | 一个 tree 1.6.0 测试包 | 手动测试上传 |

## 2. 现有 CI 推送链路的问题

目前只有 2 个仓库有 `upload-nexus.yml`(tag 推送触发),核查了全部历史 run 日志:

### libtriton_jit:显示成功,实为空跑

最近两次 run(05-26、05-27)状态是 SUCCESS,但日志里是:

```
curl: (3) URL using bad/illegal format or missing URL
Uploaded 0 deb package(s)
Uploaded 0 rpm package(s)
```

原因:仓库没有配置 `NEXUS_APT_URL` / `NEXUS_YUM_URL` 这两个 secret,URL 展开成了空字符串。脚本里的失败处理写法有缺陷(bash `set -e` 不捕获 `if` 条件中的函数返回值),所以 0 个包上传也显示绿色。

→ 复查入口:libtriton_jit Actions run `26499200640`

### FlagCX:7 次 run 全部失败,三层原因

| 层 | 占比 | 现象 |
|---|---|---|
| ① 内部 runner 连不上 GitHub | 5/7 | workflow 跑在 `h20` self-hosted runner 上,下载 action 本体(codeload.github.com)就超时,死在 Set up job,一个步骤都没执行过 |
| ② artifact 过期 | 2/7 | 网络通过的两次,7 天保留期内没有可下载的构建产物——`build-deb.yml` 在 main 上从 2026-03-03 之后就没有成功产出过 |
| ③ secret 配错(潜伏) | 未触达 | upload 步骤引用的是 `REGISTRY_USERNAME` / `CONTAINER_REGISTRY`(容器 registry 的命名),且 Nexus URL 硬编码。因为前两层拦截,这一步从来没被执行到;即使修好①②,这里大概率是下一个失败点 |

第①层有个值得注意的事实:Nexus 上传这个动作本身只需要一条到 resource.flagos.net 的出站 HTTPS,对 GitHub 的依赖(拉 action、拉 artifact)在 GitHub-hosted runner 上不存在网络问题。

## 3. 修复方案:两个选项,请大家给意见

### 选项 A:每个仓库自带 upload-nexus.yml

13 份标准化 workflow 文件已备好(统一 secret 命名、GitHub-hosted runner、修复了"空跑显示绿色"的问题),逐仓库提 PR。

代价:

1. **凭据扩散**:Nexus 凭据要对 13 个仓库的 Actions 可见,任何能改这些仓库 workflow 的人都能读到;泄露排查要覆盖 13 个仓库
2. **配置/轮换成本**:secret 变更要同步 13 处(org-level secret 可收敛成 1 处,但需要 org 管理员操作)
3. **维护成本**:模板每改一次就是 13 个 PR。这次发现的静默失败 bug 就是现成例子——两个仓库的旧版各自带病运行了 3 个月没人发现
4. 占用各仓库 maintainer 的 review 带宽

好处:

1. tag 推送即时上传,无延迟
2. 失败红在产物所属的仓库,归属直观

### 选项 B:中央仓库统一推送

在 flagos-packaging 加一个统一的上传 workflow:按组件清单跨仓拉取构建产物(公开仓库只需要 GITHUB_TOKEN,上游 13 个仓库零配置零改动),统一推送 Nexus。

好处:

1. Nexus 凭据只存在 1 个仓库,轮换/审计/撤销单点完成
2. 上游不需要任何 PR、任何 secret
3. 上传逻辑单份维护,修一处全局生效
4. 与现有架构一致(上游构建、中央发布,见 flagos-packaging ADR-001),Nexus 作为发布的第二个存储后端

代价:

1. 不是 tag 即时触发(中央按周 cron + 手动 dispatch;以后可以用 repository_dispatch 让上游打 tag 时通知中央,补上即时性)
2. 受 7 天 artifact 保留窗口约束(现有周度 cron 已经在管理这个约束)

两个选项不互斥:也可以先用一种跑通,某个组件有特殊需求时再单独加另一种。

## 4. 无论选哪个,需要管理员做的事

1. **Nexus 侧**:确认/创建部署账号。建议建一个 CI 专用账号,只授予 3 个发布目标仓的写权限(目前手动上传用的账号疑似全局管理员,给 CI 用面太宽)
2. **GitHub 侧**:配置 4 个 secret
   - `NEXUS_USERNAME` / `NEXUS_PASSWORD`:部署账号凭据
   - `NEXUS_APT_URL` = `https://resource.flagos.net/repository/flagos-apt-hosted`
   - `NEXUS_YUM_URL` = `https://resource.flagos.net/repository/flagos-yum-hosted`
   - 选 B 只配 flagos-packaging 一个仓库;选 A 要配 org-level 并选中 13 个仓库
3. **方案拍板**:A 还是 B

配好后的验证很便宜:手动 dispatch 一次上传 workflow,看包是否出现在 Nexus 且时间戳和 run 对得上。修复版 workflow 已带 fail-loud 检查,配置不对会直接红,不会再出现"绿色但 0 上传"。

## 5. 参考

- 详细调查与英文版文档:flagos-packaging `docs/nexus-integration.md`
- 13 份标准 workflow 模板:flagos-packaging `templates/per-repo/`
- 日志证据:libtriton_jit run 26499200640;FlagCX runs 21636863118 ~ 26732928459
