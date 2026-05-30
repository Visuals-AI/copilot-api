# Copilot API + New-API 集成部署 SOP

> 本文档提供将 [copilot-api](https://github.com/ericc-ch/copilot-api) 与 [new-api](https://github.com/Calcium-Ion/new-api) 网关集成的完整操作流程。
>
> copilot-api 是 GitHub Copilot API 的反向代理，将其暴露为 OpenAI/Anthropic 兼容接口；new-api 作为统一网关聚合多个渠道。两者配合，可将 GitHub Copilot 模型接入任何支持 OpenAI API 的工具。
>
> **详细英文文档请参考 [README.md](./README.md)。**

---

## 目录

1. [前置条件](#1-前置条件)
2. [目录结构说明](#2-目录结构说明)
3. [Docker 网络配置](#3-docker-网络配置)
4. [启动顺序：先启动 new-api](#4-启动顺序先启动-new-api)
5. [启动 copilot-api](#5-启动-copilot-api)
6. [GitHub 设备授权流程](#6-github-设备授权流程)
7. [new-api 渠道配置](#7-new-api-渠道配置)
8. [验证与测试](#8-验证与测试)
9. [模型推荐](#9-模型推荐)
10. [常见问题排查](#10-常见问题排查)

---

## 1. 前置条件

开始前，请确保满足以下条件：

- [ ] **Docker** 和 **Docker Compose** 已安装
- [ ] **new-api** 已部署运行（docker-compose 或其他方式）
- [ ] **GitHub 账号** 已开通 [GitHub Copilot](https://github.com/settings/copilot) 订阅
- [ ] **网络环境** 可正常访问 `github.com` 和 `api.github.com`
- [ ] 当前工作目录已克隆 [copilot-api](https://github.com/ericc-ch/copilot-api) 项目

---

## 2. 目录结构说明

```
copilot-api/
├── docker-compose.yml    # Docker Compose 配置文件（关联 new-api 网络）
├── copilot-data/         # 认证令牌持久化目录（自动创建）
├── README.md             # 完整英文文档
└── start.bat             # Windows 本地启动脚本（非 Docker 场景）
```

> **说明**：`docker-compose.yml` 的具体内容请直接查看文件本身或 [README.md](./README.md#docker-compose-configuration)。本文档不重复粘贴，可对照阅读。

---

## 3. Docker 网络配置

copilot-api 需要与 new-api 处于**同一个 Docker 网络**中才能通信。

### 3.1 检查 new-api 网络

new-api 启动后会自动创建一个名为 `new-api_new-api-network` 的 Docker 网络。验证网络是否存在：

```sh
docker network ls | grep new-api
```

预期输出中包含：

```
new-api_new-api-network   bridge   local
```

### 3.2 若网络不存在

如果未看到上述网络，说明 new-api 尚未启动或网络名称不同。请先确保 new-api 已正常运行：

```sh
# 进入 new-api 项目目录，确认容器正在运行
cd /path/to/new-api
docker-compose ps
```

> **详细说明**请参考 [README.md > Docker Network Setup](./README.md#docker-network-setup)。

---

## 4. 启动顺序：先启动 new-api

> ⚠️ **关键要求**：new-api **必须**在 copilot-api **之前**启动，因为 copilot-api 依赖 new-api 的 Docker 网络。

### 4.1 启动 new-api

```sh
cd /path/to/new-api
docker-compose up -d
```

### 4.2 验证 new-api 运行正常

```sh
# 检查容器状态
docker-compose ps

# 查看运行日志
docker logs new-api --tail 20
```

确认 new-api 容器状态为 `Up`，且日志无异常报错。

---

## 5. 启动 copilot-api

### 5.1 构建并启动

```sh
cd /path/to/copilot-api
docker-compose up -d
```

### 5.2 验证容器运行状态

```sh
docker ps | grep copilot-api
```

预期输出：容器状态为 `Up`。

### 5.3 查看初始日志

```sh
docker logs copilot-api
```

首次启动时，日志会显示 GitHub 认证提示，要求按 Enter 开始设备授权流程。

---

## 6. GitHub 设备授权流程

copilot-api **首次启动时需要进行 GitHub OAuth 设备授权**。认证成功后令牌会持久化到 `./copilot-data` 目录，后续重启无需重复授权。

### 6.1 步骤一：进入容器交互模式

```sh
docker attach copilot-api
```

此时会看到终端显示认证提示信息，类似：

```
Press Enter to open the browser for GitHub device authorization...
```

### 6.2 步骤二：触发授权流程

按 **Enter** 键，终端将显示设备授权码：

```
Device code: XXXX-XXXX
Open https://github.com/login/device in your browser
```

### 6.3 步骤三：完成 GitHub 授权

1. 打开浏览器，访问 **https://github.com/login/device**
2. 输入终端中显示的 **Device Code**（如 `XXXX-XXXX`）
3. 点击 **Continue** / **Authorize**
4. 在授权页面确认授予 **GitHub Copilot** 相关权限

### 6.4 替代方案：使用 auth 命令

如果 `docker attach` 方式不方便，可以直接在容器内执行 auth 命令：

```sh
docker exec -it copilot-api copilot-api auth
```

同样会触发设备授权流程，按提示操作即可。

### 6.5 步骤四：重启 copilot-api

授权完成后，退出容器（`Ctrl+P, Ctrl+Q`），然后重启：

```sh
docker restart copilot-api
```

### 6.6 验证认证状态

```sh
docker logs copilot-api --tail 20
```

确认日志中没有认证错误，显示服务正常启动，监听在 `0.0.0.0:4141`。

> **更多认证选项**（如 `--github-token`、`--account-type` 等）请参考 [README.md > Command Line Options](./README.md#command-line-options)。

---

## 7. New-API 渠道配置

### 7.1 登录 new-api 管理后台

在浏览器中打开 new-api 管理后台（默认 `http://<your-server>:3000`），使用管理员账号登录。

### 7.2 添加自定义渠道

导航到 **渠道管理** → **添加渠道**，填写以下字段：

| 配置字段 | 填写值 | 说明 |
|---------|--------|------|
| **类型** | `Custom` | 选择自定义渠道类型 |
| **名称** | `copilot-api` | 可自定义，建议见名知意 |
| **Base URL** | `http://copilot-api:4141` | ⚠️ 必须使用容器名 `copilot-api`，不能用 `localhost` |
| **API Key** | `dummy` | copilot-api 不校验此值，任意非空字符串均可 |
| **模型** | `gpt-4o,gpt-4o-mini,gpt-4.1,claude-sonnet-4.5,gemini-2.5-pro` | 用英文逗号分隔，每个模型名对应一个 Copilot 可用模型 |

### 7.3 字段说明

| 字段 | 说明 |
|------|------|
| **Type** | 必须选 `Custom` 才能与 copilot-api 兼容 |
| **Base URL** | `http://copilot-api:4141` — 这是 Docker 容器间的内部通信地址。容器名 `copilot-api` 由 Docker DNS 自动解析到 copilot-api 容器的 IP。**不要**使用 `localhost` 或 `127.0.0.1`，因为从 new-api 容器内看，`localhost` 指向的是 new-api 自身 |
| **API Key** | copilot-api 忽略此值。`dummy` 是约定俗成的占位符，可填写任意非空字符串 |
| **Models** | 列出 copilot-api 支持的所有模型。详见 [README.md > Available Models](./README.md#available-models) |

### 7.4 保存并测试

点击 **保存**。保存后可在渠道列表中找到刚添加的 `copilot-api` 渠道，点击 **测试** 按钮验证连通性。

---

## 8. 验证与测试

### 8.1 查询可用模型

使用 curl 通过 new-api 查询模型列表：

```sh
curl http://<your-server>:3000/v1/models \
  -H "Authorization: Bearer <your-new-api-key>"
```

预期返回中应包含 `gpt-4o`、`gpt-4o-mini` 等模型。

### 8.2 测试对话请求

```sh
curl http://<your-server>:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-new-api-key>" \
  -d '{
    "model": "gpt-4o",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

预期返回 OpenAI 格式的完整响应，包含 `choices` 和 `usage` 字段。

### 8.3 检查 copilot-api 日志

```sh
docker logs copilot-api --tail 50
```

查看请求是否被正确转发处理，确认无认证或限流错误。

### 8.4 检查 new-api 日志

```sh
docker logs new-api --tail 50
```

确认 new-api 正确路由请求到 copilot-api 渠道。

---

## 9. 模型推荐

不同使用场景建议的模型选择：

| 使用场景 | 推荐模型 | 说明 |
|---------|---------|------|
| **通用场景** | `gpt-4o` | 能力与速度均衡，日常使用首选 |
| **快速/简单任务** | `gpt-4o-mini` | 低延迟、低消耗，适合简单对话 |
| **编程与推理** | `claude-sonnet-4.5` 或 `gpt-4.1` | 复杂编程任务和深度推理 |
| **长文本分析** | `gemini-2.5-pro` | 大上下文窗口，适合长文档处理 |

> **完整模型列表**请参考 [README.md > Available Models](./README.md#available-models)。

---

## 10. 常见问题排查

### Q1: 无法连接到 copilot-api

**症状**：new-api 测试渠道时返回连接超时或连接拒绝。

**排查步骤**：

1. 确认 copilot-api 容器正在运行：
   ```sh
   docker ps | grep copilot-api
   ```

2. 确认网络连通性：
   ```sh
   docker exec new-api ping copilot-api
   ```

3. 确认 copilot-api 内部端口正常：
   ```sh
   docker logs copilot-api --tail 20
   ```
   应看到类似 `Listening on 0.0.0.0:4141` 的输出。

### Q2: GitHub 认证失败

**症状**：copilot-api 启动后日志显示认证错误。

**排查步骤**：

1. 重新执行认证流程：
   ```sh
   docker exec -it copilot-api copilot-api auth
   ```

2. 检查 GitHub 账号的 Copilot 订阅是否有效：访问 [https://github.com/settings/copilot](https://github.com/settings/copilot)

3. 清除缓存的令牌后重试：
   ```sh
   # 删除认证数据目录后重启（会重新触发授权流程）
   rm -rf copilot-data/*
   docker restart copilot-api
   ```

### Q3: 请求返回 429 限流错误

**症状**：频繁请求时报 rate limit 错误。

**解决方案**：

1. 在 new-api 中配置**重试**和**限流**策略
2. copilot-api 支持 `--rate-limit` 和 `--wait` 参数，可限制请求速率
3. 减少并发请求数

> 详细说明请参考 [README.md > Usage Tips](./README.md#usage-tips)。

### Q4: 部分模型不可用

**症状**：`gpt-4.1` 或 `claude-sonnet-4.5` 等模型返回 404 / not found。

**可能原因**：

1. GitHub Copilot 订阅类型不同（个人/企业/商业版）支持不同的模型集
2. 可在 new-api 渠道配置中按需调整 `Models` 字段，移除不可用的模型
3. 使用 `--account-type` 参数指定账号类型：
   ```sh
   # 企业版账号
   docker exec copilot-api copilot-api start --account-type enterprise
   ```

### Q5: copilot-api 无法访问外网(GitHub)

**症状**：认证流程中无法获取 device code，或启动后无法转发请求。

**排查**：

1. 检查宿主机的网络代理设置
2. 如果通过代理访问 GitHub，copilot-api 支持 `--proxy-env` 参数（会自动读取 `HTTP_PROXY` / `HTTPS_PROXY` 环境变量）
3. 在 `docker-compose.yml` 中配置环境变量：
   ```yaml
   environment:
     - HTTP_PROXY=http://your-proxy:port
     - HTTPS_PROXY=http://your-proxy:port
   ```

### Q6: 容器重启后需要重新认证

**症状**：每次重启都要求重新进行 GitHub 授权。

**排查**：

1. 确认 `docker-compose.yml` 中 volumes 挂载正确：
   ```yaml
   volumes:
     - ./copilot-data:/root/.local/share/copilot-api
   ```
2. 确认 `./copilot-data` 目录已存在且包含令牌文件
3. 检查目录权限：Docker 容器以非 root 用户运行，确保 `./copilot-data` 可写

---

## 附录

### A. 参考链接

| 资源 | 链接 |
|------|------|
| copilot-api 项目 | [https://github.com/ericc-ch/copilot-api](https://github.com/ericc-ch/copilot-api) |
| new-api 项目 | [https://github.com/Calcium-Ion/new-api](https://github.com/Calcium-Ion/new-api) |
| 完整英文文档 | [README.md](./README.md) |
| GitHub 设备授权 | [https://github.com/login/device](https://github.com/login/device) |
| GitHub Copilot 设置 | [https://github.com/settings/copilot](https://github.com/settings/copilot) |

### B. 快速命令速查

| 操作 | 命令 |
|------|------|
| 启动 new-api | `cd /path/to/new-api && docker-compose up -d` |
| 启动 copilot-api | `cd /path/to/copilot-api && docker-compose up -d` |
| 查看 copilot-api 日志 | `docker logs copilot-api` |
| 执行认证 | `docker exec -it copilot-api copilot-api auth` |
| 重启 copilot-api | `docker restart copilot-api` |
| 检查模型列表 | `curl http://localhost:3000/v1/models -H "Authorization: Bearer <key>"` |
| 测试对话 | `curl http://localhost:3000/v1/chat/completions -H "Content-Type: application/json" -H "Authorization: Bearer <key>" -d '{"model":"gpt-4o","messages":[{"role":"user","content":"hello"}]}'` |

---

> **最后更新**：2026-05-30
