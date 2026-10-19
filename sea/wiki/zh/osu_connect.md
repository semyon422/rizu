> 本页由 AI 翻译!!! 可能包含令人困惑的错误，但希望您仍然能够理解这里解释的内容。如果您害怕机器人，请阅读原始英文页面！

# 从 osu! 连接
您可以使用 osu!stable 在 <%= brand.name %> 上游玩。

1. 为 `osu!.exe` 创建快捷方式。
2. 打开快捷方式的属性，在 **目标** 字段末尾添加 `-devserver` 参数:

```
C:\Users\user\AppData\Local\osu!\osu!.exe -devserver <%= (brand.url:gsub("^https?://", "")) %>
```

如果游戏安装在其他位置，请将路径替换为实际路径。

3. 至少 [在网站上登录](/login) 一次。这会创建您的账号。
4. 通过新的快捷方式启动 osu!，并使用您的 <%= brand.name %> 账号登录。

请始终使用此快捷方式在 <%= brand.name %> 上游玩。正常启动 osu! 会连接到官方服务器。
