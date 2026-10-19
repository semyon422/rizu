> 本頁由 AI 翻譯!!! 可能包含令人困惑的錯誤，但我想您仍然能夠理解這裡解釋的內容。如果您害怕機器人，請閱讀原始英文頁面！

# 從 osu! 連線
您可以使用 osu!stable 在 <%= brand.name %> 上遊玩。

1. 為 `osu!.exe` 建立捷徑。
2. 開啟捷徑的內容，在 **目標** 欄位末尾加入 `-devserver` 參數:

```
C:\Users\user\AppData\Local\osu!\osu!.exe -devserver <%= (brand.url:gsub("^https?://", "")) %>
```

如果遊戲安裝在其他位置，請將路徑替換為實際路徑。

3. 至少 [在網站上登入](/login) 一次。這會建立您的帳號。
4. 透過新的捷徑啟動 osu!，並使用您的 <%= brand.name %> 帳號登入。

請始終使用此捷徑在 <%= brand.name %> 上遊玩。正常啟動 osu! 會連線到官方伺服器。
