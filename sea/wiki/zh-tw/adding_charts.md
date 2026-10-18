> 本頁由 AI 翻譯!!! 可能包含令人困惑的錯誤，但我想您仍然能夠理解這裡解釋的內容。如果您害怕機器人，請閱讀原始英文頁面！

# 新增歌曲
有四種方式可以將歌曲新增到 <%= brand.name %>。我們建議您熟悉所有這些方式。

<%= brand.name %> 支援以下歌曲格式：
- `.osu` - 來自 **osu!** 的譜面
- `.qua` - 來自 **Quaver** 的歌曲
- `.sm` 和 `.ssc` - 來自 **StepMania** 和 **Etterna** 的歌曲
- `.bms`, `.bme`, `.bml` 和 `.pms` - 來自 **Lunatic Rave 2**, **beatoraja** 和其他 **Beatmania** 模擬器的歌曲
- `.ojn` - 來自 **o2jam** 的歌曲
- `.ksh` - 來自 **K-Shoot MANIA** 的歌曲
- `.sph` - 來自 **<%= brand.name %>** 的歌曲
- `.mid` 和 `.midi`。

在頁面的最後，您可以找到歌曲下載連結。

## 從文件夾新增歌曲庫
使用此方法，您可以指定磁碟上的歌曲文件夾路徑。這是新增您計算機上安裝的其他節奏遊戲所有歌曲的最佳方式。遊戲會從您指定的位置讀取，而無需複製文件。

首先，您需要找到歌曲文件夾，它可能是 **osu!**, **Quaver** 或 **Etterna** 的 `Songs` 文件夾，或只是一個包含歌曲的文件夾。我們感興趣的是具有以下文件層級結構的文件夾（**osu!** 和 **Quaver**）：
```
songs_folder/
├── song1/
│ ├── audio.mp3
│ ├── easy.osu
│ └── hard.osu
├── song2/
├── song3/
```

<%= brand.name %> 也支援從子文件夾中搜索歌曲（**Etterna** 和 **StepMania**）：
```
songs_folder/
├── pack1/
│ ├── song1/
│ │ ├── audio.mp3
│ │ └── chart.sm
│ ├── song2/
│ └── song3/
├── pack2/
├── pack3/
```

新增歌曲的這種方法需要一個根文件夾，在上面的例子中是 `songs_folder`，在 **osu!**, **Quaver** 和 **Etterna** 的情況下，它將是 `Songs` 文件夾。

1. 啟動 <%= brand.name %>。
2. 點擊屏幕底部的 `Locations` 按鈕。
3. 點擊右下角的 `Add location`。
4. 在文字框中輸入名稱。
5. 點擊 `Choose folder` 開啟檔案對話框，選擇包含歌曲的文件夾。您也可以手動輸入路徑。
6. 點擊 `Add location`。
7. 在列表中新出現的行上點擊 `Update cache`。

> 歌曲快取是非同步進行的，快取期間您可以正常玩遊戲。選歌介面會出現 `Add new charts` 按鈕，點擊後會將新歌曲新增到列表中。

## 將新歌曲新增到 <%= brand.name %> 文件夾
<%= brand.name %> 有自己的歌曲文件夾，您可以在其中放置任何格式的歌曲。此文件夾位於相對於遊戲根目錄的路徑：`userdata/charts/`。您應該在子文件夾中新增新歌曲。

1. 前往 `userdata/charts/`。
2. 創建一個文件夾，您將在此文件夾中放置歌曲。例如，路徑如下：`userdata/charts/cool_songs/`。
3. 在此文件夾中放置歌曲或包（包含歌曲的子文件夾）。
4. 進入遊戲，點擊屏幕底部的 `Locations` 按鈕。
5. 確保列表中有 `<%= brand.location_name %>` 位置。點擊其所在行的 `Update cache`，然後在選歌介面點擊 `Add new charts`。

## 在遊戲內下載歌曲 (DLC)
您可以直接在遊戲內下載 **osu!** 歌曲和 **Etterna**/**StepMania** 曲包。

1. 在主選單中，點擊底部的 `DLC` 按鈕。
2. 選擇想要的歌曲或曲包並下載。

## 新增 `.osz` 歌曲
1. 將 `.osz` 拖到遊戲窗口中。
2. 完成。

## 下載連結
> 我們與以下列出的網站無任何聯繫。請自行承擔風險從這些網站下載文件。

在本節中，我們選取了一些網站，您可以輕鬆地從這些網站下載歌曲。
- [**osu.ppy.sh**](https://osu.ppy.sh/beatmapsets) `.osu` 格式。需要註冊。
- [**quavergame.com**](https://quavergame.com/maps) `.qua` 格式。需要通過 `Steam` 註冊。
- [**etternaonline.com**](https://etternaonline.com/packs) `.sm` 和 `.ssc` 格式。
- [**search.stepmaniaonline.net**](https://search.stepmaniaonline.net/) `.sm` 和 `.ssc` 格式。
