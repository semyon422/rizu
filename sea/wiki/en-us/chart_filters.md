# Chart Filters
The game offers several ways to filter your chart collection.

## Difficulty Calculator
Each of the calculators calculates difficulty differently, so you can choose from the following calculators:
- **ENPS** - extended notes per second  
- **osu!** star rate  

1. Open the game settings by clicking on the gear icon in the lower left corner of the screen in the song selection menu.  
2. Go to the `select` tab  
3. Select the desired difficulty calculator from the `difficulty` drop down list  
4. Reload the game OR go to `collections` and back to `notecharts`.

The game will then display the selected difficulty.  
You can sort by difficulty by selecting `difficulty` from the drop down list at the top chart of the screen in the song selection.

## Filter Menu
We've made a handy menu for quick filtering by number of keys, chart format, and played/unplayed chart filter.  

In the song selection menu, click on the `filters` button at the top right of the screen.
There you will see several types of filters.

- **original input mode** The initial number of keys on the chart. This is the normal filter for the number of keys.  
- **actual input mode** A special filter for charts converted to other modes using modifiers.  
- **format** A filter for chart format, more like a filter for chart from games.  
- **extension** Filter by chart format.  
- **(not) played** Filter for played/not played charts.  
- **scratch** Designed for BMS charts, where there is a special column for disk.  

## Filters by charts played and mods applied
The game has a unique feature to show played charts as individual charts.  
For example: the normal chart list is more like a file view. If you create a chart, it is saved to a file. Charts are merged into a set of charts if they are in the same folder as the song. <%= brand.name %> allows you to show played charts as separate charts. This is useful if you want to see and play what you have played before with the same mod combination. This feature will become much more useful with more charts played.

To change the chart display mode, in the chart selection list, which is the list down the middle, click on the `charts` button.  
There are three modes to choose from: 
- **charts** - normal list of charts
- **diffs** - the usual list of charts, which also displays previously played charts with applied mods.
- **plays** - the list of charts is replaced by the list of played charts, as if you were going through the list of scores. Most useful if you sort the list by `last played`.

Examples:
If you played a chart with the `FLN3` mod, it will show as a separate chart in **diffs** and **plays**.  **diffs** will show the original chart and the chart with `FLN3` as separate charts. **plays** will show it as a separate chart, and each record set is a separate chart.

We recommend you to play and understand it yourself in practice. 

## Search Filters
By typing in search or lamp you will be able to filter the list by certain criteria. 
You can use the following comparison marks: 
- `=` equals  
- `~=` is not equal  
- `!=` is not equal  
- `<` less  
- `>` more  
- `<=` less or equal  
- `>=` greater than or equal to  

Example: `dj sharpnel difficulty>10 difficulty<20` - the list of charts will output charts that are with the artist `DJ SHARPNEL` and have a difficulty between 10 and 20.  

Filters:
- Difficulty: `difficulty`, `diff`, `d`.  
- Chart duration: `duration`, `dur`, `len`, `l`  
- BPM: `bpm`, `b`, `tempo`, `t`.  
- Number of notes: `notes_count`, `nc`, `obj`.  
- Level (**StepMania** and **o2jam**): `level`, `lv`.
- Percentage of long notes (0-100): `ln`.
- Number of misses on scores: `miss`, `m`
- Accuracy on scores: `accuracy`, `acc`, `a`.
- Number of points on scores: `score`, `s`
