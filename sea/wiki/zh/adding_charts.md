> 本页由 AI 翻译!!! 可能包含令人困惑的错误，但希望您仍然能够理解这里解释的内容。如果您害怕机器人，请阅读原始英文页面！

# 添加歌曲
有四种方式可以将歌曲添加到 <%= brand.name %>。我们建议您熟悉所有这些方式。

<%= brand.name %> 支持以下歌曲格式：
- `.osu` - 来自 **osu!** 的谱面
- `.qua` - 来自 **Quaver** 的歌曲
- `.sm` 和 `.ssc` - 来自 **StepMania** 和 **Etterna** 的歌曲
- `.bms`, `.bme`, `.bml` 和 `.pms` - 来自 **Lunatic Rave 2**, **beatoraja** 和其他 **Beatmania** 模拟器的歌曲
- `.ojn` - 来自 **o2jam** 的歌曲
- `.ksh` - 来自 **K-Shoot MANIA** 的歌曲
- `.sph` - 来自 **<%= brand.name %>** 的歌曲
- `.mid` 和 `.midi`。

在页面的最后，您可以找到歌曲下载链接。

## 从文件夹添加歌曲库
使用此方法，您可以指定磁盘上的歌曲文件夹路径。这是添加您计算机上安装的其他节奏游戏所有歌曲的最佳方式。游戏会从您指定的位置读取，而无需复制文件。

首先，您需要找到歌曲文件夹，它可能是 **osu!**, **Quaver** 或 **Etterna** 的 `Songs` 文件夹，或只是一个包含歌曲的文件夹。我们感兴趣的是具有以下文件层级结构的文件夹（**osu!** 和 **Quaver**）：
```
songs_folder/
├── song1/
│ ├── audio.mp3
│ ├── easy.osu
│ └── hard.osu
├── song2/
├── song3/
```

<%= brand.name %> 也支持从子文件夹中搜索歌曲（**Etterna** 和 **StepMania**）：
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

添加歌曲的这种方法需要一个根文件夹，在上面的例子中是 `songs_folder`，在 **osu!**, **Quaver** 和 **Etterna** 的情况下，它将是 `Songs` 文件夹。

1. 启动 <%= brand.name %>。
2. 点击屏幕底部的 `Locations` 按钮。
3. 点击右下角的 `Add location`。
4. 在文本框中输入名称。
5. 点击 `Choose folder` 打开文件对话框，选择包含歌曲的文件夹。您也可以手动输入路径。
6. 点击 `Add location`。
7. 在列表中新出现的行上点击 `Update cache`。

> 歌曲缓存是异步进行的，缓存期间您可以正常玩游戏。选歌界面会出现 `Add new charts` 按钮，点击后会将新歌曲添加到列表中。

## 将新歌曲添加到 <%= brand.name %> 文件夹
<%= brand.name %> 有自己的歌曲文件夹，您可以在其中放置任何格式的歌曲。此文件夹位于相对于游戏根目录的路径：`userdata/charts/`。您应该在子文件夹中添加新歌曲。

1. 前往 `userdata/charts/`。
2. 创建一个文件夹，您将在此文件夹中放置歌曲。例如，路径如下：`userdata/charts/cool_songs/`。
3. 在此文件夹中放置歌曲或包（包含歌曲的子文件夹）。
4. 进入游戏，点击屏幕底部的 `Locations` 按钮。
5. 确保列表中有 `<%= brand.location_name %>` 位置。点击其所在行的 `Update cache`，然后在选歌界面点击 `Add new charts`。

## 在游戏内下载歌曲 (DLC)
您可以直接在游戏内下载 **osu!** 歌曲和 **Etterna**/**StepMania** 曲包。

1. 在主菜单中，点击底部的 `DLC` 按钮。
2. 选择想要的歌曲或曲包并下载。

## 添加 `.osz` 歌曲
1. 将 `.osz` 拖到游戏窗口中。
2. 完成。

## 下载链接
> 我们与以下列出的网站没有任何联系。请自行承担风险从这些网站下载文件。

在本节中，我们选取了一些网站，您可以轻松地从这些网站下载歌曲。
- [**osu.ppy.sh**](https://osu.ppy.sh/beatmapsets) `.osu` 格式。需要注册。
- [**quavergame.com**](https://quavergame.com/maps) `.qua` 格式。需要通过 `Steam` 注册。
- [**etternaonline.com**](https://etternaonline.com/packs) `.sm` 和 `.ssc` 格式。
- [**search.stepmaniaonline.net**](https://search.stepmaniaonline.net/) `.sm` 和 `.ssc` 格式。
