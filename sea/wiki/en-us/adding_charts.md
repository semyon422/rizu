# Adding charts/music
There are 4 ways to add charts to <%= brand.name %>. We recommend to familiarize yourself with all of them.

<%= brand.name %> supports the following chart formats:
- `.osu` - beatmaps from **osu!**
- `.qua` - charts from **Quaver**.
- `.sm` and `.ssc` - charts from **StepMania** and **Etterna**.
- `.bms`, `.bme`, `.bml` and `.pms` - charts from **Lunatic Rave 2**, **beatoraja** and other **Beatmania** simulators
- `.ojn` - charts from **o2jam**
- `.ksh` - charts from **K-Shoot MANIA**
- `.sph` - charts from **<%= brand.name %>**
- `.mid` and `.midi`.

At the very end of the page you can find links to the chart download pages.

## Adding a chart library from a folder
Using this method you will be able to specify the path to a folder with charts on disk. This is the best way to add all the charts from other rhythm games installed on your computer. The game will read from the location you specified without copying files.

First you need to find the folder with the charts, it can be the `Songs` folder from **osu!**, **Quaver** or **Etterna**, or just a folder with the charts in it. We are interested in folders with this file hierarchy (**osu!** and **Quaver**):
```
songs_folder/
├── song1/
│ ├── audio.mp3
│ ├── easy.osu
│ └── hard.osu
├── song2/
├── song3/
```

<%= brand.name %> also supports searching for charts from subfolders (**Etterna** and **StepMania**):
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

This method of adding charts requires a root folder, in the examples above it is `songs_folder`, in the case of **osu!**, **Quaver** and **Etterna** it will be the `Songs` folder.

1. Start <%= brand.name %>.
2. Click the `Locations` button on the bottom of the screen.
3. Click `Add location` on the bottom right side.
4. Specify the name in the textbox.
5. Click `Choose folder` to open a file dialog and select the folder with charts. You can also enter the path manually.
6. Click `Add location`.
7. Click `Update cache` on the newly appeared row in the list.

> Chart caching is asynchronous, you can play the game while it caches. In song select there will be an `Add new charts` button that updates the list with newly cached charts.

## Adding new charts to the <%= brand.name %> folder
<%= brand.name %> has its own charts folder where you can put charts of any format. This folder is located at the path: `userdata/charts/` relative to the root of the game. You should add new charts in subfolders.

1. Go to `userdata/charts/`.
2. Create a folder in which you will put the charts. For example, the path would be as follows: `userdata/charts/cool_songs/`.
3. In this folder put charts or packs (subfolders with charts).
4. Go into the game and click the `Locations` button on the bottom of the screen.
5. Make sure the `<%= brand.location_name %>` location is in the list. Click `Update cache` on its row, then click `Add new charts` in song select.

## Downloading charts in the game (DLC)
You can download **osu!** charts and **Etterna**/**StepMania** packs right in the game.

1. In the main menu, click the `DLC` button on the bottom.
2. Pick the chart or pack you want and download it.

## Adding `.osz` charts 
1. Drag `.osz` into the game window.
2. That's it.

## Download links
> We have no affiliation with the sites listed below. Download files from them at your own risk.  

In this section we have selected sites where you can easily download charts.
- [**osu.ppy.sh**](https://osu.ppy.sh/beatmapsets) `.osu` format. Registration is required.
- [**quavergame.com**](https://quavergame.com/maps) `.qua` format. Registration via `Steam` is required
- [**etternaonline.com**](https://etternaonline.com/packs) `.sm` and `.ssc` format. 
- [**search.stepmaniaonline.net**](https://search.stepmaniaonline.net/) `.sm` and `.ssc` format.

## Links to download BMS and PMS
We have tried to put together a collection of working links and tried to explain how to download charts from these sources.

> *Some* sites use HTTP connection, it's not secure.  
> Please be sure to **stay on the Torrent distribution after downloading!** Every year it becomes harder and harder to download some of the archives because people stop distributing them.

### [LUMINOUS](https://l-bms.space/)
[First pack (2.9GB)](https://slime.kr/downloads/luminous/Luminous%20PACK%201.0.1.rar) Direct link.  
[Second pack (2.7GB)](http://slime.kr/downloads/luminous/Pure%20White%20Full%20Package.rar) Direct link.

### [Toy Musical](https://tm2.toymusical.net/download.html)
[First pack (0.43GB)](https://tm2.toymusical.net/download/dl.php?dl=tm1) Direct link.  
[Second pack (0.51GB)](https://tm2.toymusical.net/download/dl.php?dl=tm2) Direct link.  
[Third pack (2.0GB)](https://www.luzeria.net/tm3/update/tm3_n2_ver296_full.zip) Direct link.  
[Third pack update (1.3GB)](https://www.luzeria.net/tm3/update/tm3_n2_ver299_sabun.zip) Direct link.  

### Korea BMS Starter Pack
[Polaris | Direct link (1.00GB)](http://musicgamelab.com:88/kbsp_polaris110.rar) Don't download if you're afraid of an HTTP connection.  
[Primrose | Direct link (1.3GB)](http://musicgamelab.com:88/KBSP_Primrose.rar) Don't download if you're afraid of an HTTP connection.  

### PABAT!
[2013 (2.1GB)](https://k-bms.com/party_pabat/event_file/PABAT_bms_event_package_total_62_bms.zip) Torrent. Inside `.zip` is `.torrent`. 16.04.2025 the distribution is active.  
[2014 (1.6GB)](https://k-bms.com/party_pabat/event_file/PABAT_2014_seasons_60bms_package.zip) Torrent. Inside `.zip` is `.torrent`. 16.04.2025 distribution is half dead.  
[2016 (3.0GB)](https://drive.google.com/file/d/0B_JSxrtTvjwHMUg2YkxGWnd1N1k/view?resourcekey=0-upgGjVZqxAjEUavBdxWz1w) Google Drive  
[2018 (1.7GB)](https://drive.google.com/file/d/13Ll_2eRMIb-Gxe7ynlMqznf-vr2DmxIV/view) Google Drive  

### Be-Music West
[Google Drive (0.6GB)](https://drive.google.com/file/d/0B7f97zxWtVlnOU1xVV9HRXcwYzg/view)

### Mumeisen
[Mumeisen11 (1.3GB)](https://drive.usercontent.google.com/download?id=0BxcEoygd7bh-Y3FpaVdmdGhCQmM&export=download&authuser=0) Google Drive  
[Mumeisen15 (3.5GB)](https://drive.google.com/file/d/1p8_4UpilwmoresANu747w07M48X2rTUY/view) Google Drive  

### [The Big Sister BMS Project](https://bms.wrigglebug.xyz/)

### [bms.kyouko.moe](https://bms.kyouko.moe/)
This is a huge collection of packs, there is an option to download individual charts and an option to download entire packs.  
The first thing we recommend is to read the [presentation](https://docs.google.com/presentation/d/1j5Xwon8NR6rTvmYCvvnbhFyeP5SAL6NYHtlHhln8nSM/edit?slide=id.p#slide=id.p) where the best way to download is described in detail.  

If you need to download individual charts, go to [this link](https://drive.google.com/drive/folders/1pJGq49KrF5St2Yfgp493oOKoDEIyZ6Hq) and then go to the `BMS Library` folder.  

Packs for **15-80GB** are in `Combined Package/Previous Packages`.  
The **Torrent** for a bunch of packs is in `Combined Package/SP Insane+ (2022-11-04)`.  

