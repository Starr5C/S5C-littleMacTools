# S5C LittleLittleArc

当前版本：`0.1.0`。版本号规则、预发布约定和 macOS 构建号映射见 [VERSIONING.md](VERSIONING.md)。

S5C LittleLittleArc 是一个个人本地 macOS 工具：通过快捷指令接收网址，生成 `~/Applications/<名称>.app`。生成的 App 不内置浏览器，只把目标 URL 交给 macOS 当前默认浏览器；当 Arc 是默认浏览器且“外部链接在 Little Arc 打开”已启用时，它会自然进入 Little Arc。

## 安装

```sh
./scripts/check.sh
./scripts/install.sh
```

然后按 [SHORTCUT.md](SHORTCUT.md) 创建本机快捷指令。安装脚本只写入 `~/Library/Application Support/S5C-LittleLittleArc/`，不创建登录项、守护进程、浏览器扩展或 Arc 自动化权限。重新安装前会将旧辅助脚本备份到同级的时间戳目录。

## 使用

从浏览器共享菜单选择 `S5C LittleLittleArc`，或单独运行它并使用剪贴板/输入框提供 URL。每次生成时：

- 默认选择“精确页面”，也可改为只保留协议、主机名和端口的“网站主页”。
- 按域名自动生成名称，例如 `chatgpt.com` 生成 `ChatGPT Web`，确认框中可直接修改。
- 通过 `favicon.is` 获取网站图标，在本地渲染成带留白的多尺寸 ICNS。网络、限流或图片格式失败时使用本地首字母图标。

也可以直接运行生成器：

```sh
"$HOME/Library/Application Support/S5C-LittleLittleArc/build-web-app.zsh" \
  --url 'https://chatgpt.com/' --mode site --name 'ChatGPT'
```

完整参数包括 `--url`、`--mode exact|site`、`--name`、`--output-dir`、`--non-interactive`、`--replace-managed` 和 `--allow-sensitive`。

## 安全与更新

只允许 HTTP/HTTPS，拒绝带用户名或密码的 URL。精确地址中出现 `token`、`auth`、`code`、`key`、`session` 或 `signature` 等查询键时会警告，因为目标 URL 会以明文存在生成 App 的 Info.plist 中。图标请求不携带 Cookie、浏览器登录态或用户凭据。

只有带 `S5CLittleLittleArcManaged=true` 标记的同名 App 才能更新；Safari Web App 或其他同名 App 不会被覆盖。构建在 `~/Applications` 同卷临时目录中完成，通过 Plist 和严格签名检查后才原子替换，替换失败会恢复旧版。

## 卸载

```sh
./scripts/uninstall.sh
```

再在“快捷指令”中删除 `S5C LittleLittleArc`。卸载不删除 `~/Applications` 中已生成的网页 App。

## 版本与发布

项目版本使用 `MAJOR.MINOR.PATCH` 语义化版本号；在 1.0 之前，新增用户可见能力递增次版本，兼容性修复和文档测试调整递增修订版本。`VERSION` 是唯一的对外版本源，`BUILD_NUMBER` 是写入生成 App 的递增数字构建号。发布时应同步更新这两个文件、README 中的当前版本，并创建 `v<version>` 标签；当前版本仍处于 1.0 之前的验证阶段。

## 边界

这是个人本地工具，生成 App 采用 ad-hoc 签名，不包含 Developer ID、公证、自动更新或公开分发能力。Little Arc 是 Arc 当前路由设置的结果，不是生成 App 的固定依赖。
