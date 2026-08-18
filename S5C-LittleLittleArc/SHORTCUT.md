# 创建“S5C LittleLittleArc”快捷指令

项目的安装脚本先把可审计的生成器放到 `~/Library/Application Support/S5C-LittleLittleArc/`。快捷指令本身只是浏览器输入适配器，不包含网站数据、Cookie 或登录态。

1. 打开“快捷指令”，新建 `S5C LittleLittleArc`。
2. 打开详细信息，启用“在共享表单中显示”，输入类型只保留 URL。
3. 添加“运行 Shell 脚本”动作，Shell 选择 `/bin/zsh`，将输入传递方式设为“作为参数”。
4. 将动作中的脚本替换为：

```zsh
builder="$HOME/Library/Application Support/S5C-LittleLittleArc/build-web-app.zsh"
if (( $# > 0 )) && [[ -n "$1" ]]; then
  exec "$builder" --url "$1"
else
  exec "$builder"
fi
```

5. 在“快捷指令 > 设置 > 高级”中启用 Allow Running Scripts。这个开关只允许快捷指令执行你能看到的本地脚本；本项目不要求管理员权限。

从浏览器共享菜单运行时，URL 会直接传入。从“快捷指令”单独运行时，生成器会先尝试剪贴板，剪贴板不是 HTTP/HTTPS 地址时再询问。

在任意确认对话框中选择“取消”会正常结束快捷指令，并通过通知和输出提示“用户已取消操作”，不会再显示 Shell 脚本错误。
