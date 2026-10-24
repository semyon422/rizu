# Rizu difficulty calculator

This document explains how Rizu's difficulty calculator works, what data it was tuned on, how its ratings become the numbers players see, and how to rebuild or retune it. The game runs it as `chart/scoring/rizucalc.lua` and stores the result in `chartdiffs.user_diff`. The Python workspace it was built in is `calc/`, and `calc/README.md` is the lab notebook with every experiment.

There are three calculators, all built the same way:

| Keymode | Calculator | Tuned against | Shown on |
|---|---|---|---|
| 4key | v2 4K | MSD (Etterna) 17–31, plus charts judged by players | MSD scale |
| 7key, 7key1scratch | v2 7K | Starlight, Satellite and Stella BMS tables | 4K scale, through the dan curve |
| 14key2scratch | v1 14K | IIDX DP levels, DP Satellite and DP Stella | IIDX DP level scale |

Every other keymode gets 0. Those keymodes see almost no play, so they have no calculator.

## What the rating means

The rating answers one question, the same one MSD answers: how hard is it to reach a fixed accuracy on this chart? It does not try to answer how hard the chart is to pass. Accuracy is counted per note, so a dense hard section weighs more than a short spike, and a few easy notes cannot make up for it.

The player has two hands, and the calculator knows which column belongs to which hand. It does not detect named patterns like "jumpstream". It works from the time between notes, how they spread over columns and hands, and how long the player has been under load.

## How a chart is rated

The input is a list of notes: start time and column. Hold ends are ignored. Only 1 of the 1412 7K table charts has 10% or more long notes, and the SRR long-note terms we tried overrated easy LN charts.

### 1. Snap rows

Times are rounded to whole milliseconds. Notes less than 3 ms after the previous row join that row, because chart previews round times to 1/1024 s and simultaneous notes can decode 1 ms apart. Rounding is half to even, like numpy, so the Lua and Python versions give the same numbers.

### 2. Hand groups

Each column belongs to a group:

- **4K:** left hand (columns 1–2) and right hand (3–4).
- **7K:** left hand (S D F), right hand (J K L) and the middle key as its own thumb group. The tuner preferred the thumb group over putting the middle key on either hand. For 7key1scratch the scratch notes are removed first, because keyboard players usually play these charts without them.
- **14K2S:** one group per side, each with 7 keys and that side's scratch. An IIDX pad and a keyboard both play it this way, so there is no finger model.

### 3. Note strain

Each note gets a strain value that grows with speed:

- **Group speed:** notes of one group at the same millisecond form a row. A row's strain is `size^chord / max(dt, min_dt)^speed_exp`, where `dt` is the time since the group's previous row. `chord` makes bigger chords harder. `speed_exp` below 1 means more notes per second raise difficulty less than proportionally, which fits 7K's three-finger hands.
- **Jacks:** `jack / max(dt, min_dt)`, where `dt` is the time since the previous note in the same column.
- **Cross-column movement** (`cross`, from Star-Rating-Rebirth): for each pair of neighbor columns, the speed of alternating between them, times a per-pair weight. 7K uses SRR's finger weights: ring–pinky pairs 0.35, pairs next to the middle key 0.225. 14K2S weighs every pair on a side alike, and keys on different sides are not neighbors.

`min_dt` caps how fast anything can count, so grace notes and flams don't explode.

### 4. Windows

The chart is cut into fixed windows: 0.25 s for 4K, 1 s for 7K and 4 s for 14K2S. For each window:

- **Speed:** the mean strain of each group, combined with a power mean across groups (`group_power`). Groups with no notes count as 0. With power 2 (4K and 7K), spreading notes over both hands rates about as high as putting them all on one hand. 14K2S uses 16, so the busier hand decides.
- **Rhythm variety** (`tech`): entropy of the quantized time between rows. Many different gaps are harder to time accurately than one steady rhythm. This is what separates varied chordjack like `thinkin bout u <3` from steady chordjack like `White Eve`.
- **Pattern variety** (`pattern`, 7K and 14K2S): entropy of which columns each row uses.
- **Anchors** (`anchor`, from SRR): how unevenly the window's notes spread over columns, when one column carries more than its share.

A window's difficulty is `speed · (1 + tech · rhythm entropy + pattern · pattern entropy) · (1 + anchor · anchor term)`.

### 5. Stamina

Two fatigue levels follow the notes per second of each window:

- **Short-term fatigue** is an exponential average over `tau` seconds, a local density boost.
- **Long-term fatigue** builds up over `long_tau` seconds but falls fast when density drops. A 5 s break restores 90% of stamina and a 10 s break 99%, as players report.

Each window's difficulty is multiplied by `(1 + stamina · short / 20) · (1 + long_stamina · long / 20)`, where 20 notes per second is the reference. Hard sections after a long run get harder, and a short spike in an easy chart does not rate like a sustained section.

### 6. Combine windows

The raw rating is a weighted power mean of window difficulties. The power (4–6) leans toward the hardest windows without letting one window decide. Each window is weighted by its note count to the power `density`, because accuracy is counted per note.

7K and 14K2S then multiply by `n / (n + 240)` for a chart with `n` notes, like SRR's short-chart nerf. 4K leaves it out: a short chart with a few hard moments still ends with bad accuracy.

## Parameters

These are the tuned values, from `calc/v2_4k.py`, `calc/v2_7k.py` and `calc/v1_14k.py`, copied into `rizucalc.lua`:

| | 4K | 7K | 14K2S |
|---|---|---|---|
| window (s) | 0.25 | 1 | 4 |
| min_dt (s) | 0.06 | 0.03 | 0.04 |
| speed_exp | 1 | 0.5 | 0.7 |
| chord | 0 | 0.5 | 0.75 |
| jack | 1.5 | 1.5 | 0.5 |
| cross | 0.25 | 1 | 0.25 |
| anchor | 0.25 | 0.5 | 0 |
| tech | 0.05 | 0.05 | 0 |
| pattern | 0 | 0.2 | 1 |
| stamina, tau (s) | 0.3, 5 | 2, 1 | 5, 10 |
| long_stamina, long_tau (s) | 0.2, 120 | 0.2, 60 | 0.8, 480 |
| power | 6 | 6 | 4 |
| density | 1 | 0.5 | 1 |
| group_power | 2 | 2 | 16 |
| short-chart nerf (notes) | none | 240 | 240 |

## What we tuned it on

All three were tuned by coordinate search: try each value in a list for one parameter, keep it if the loss drops, and repeat until nothing improves. The search code is in `calc/tune_4k.py`. Each tuner tunes on half the charts and reports results on the other half.

The loss is about order, not exact values: `100 · (1 − Spearman)`, the rank correlation between ratings and the reference. The numbers players see come later, from a separate mapping onto a scale.

### 4K: MSD plus player judgment

- **Reference:** stored MSD for charts at MSD 17–31, the range where MSD orders charts well. Above that, MSD crowds charts from playable to Epsilon-clear level together.
- **Known MSD bias:** dense chordjack is heavily underrated and handstream is slightly overrated, so MSD is a reference, not ground truth.
- **Player-judged targets** in `calc/tune_4k.py` add penalties:
  - `ANCHORS` gives a chart a range on the MSD scale. For example, The Violation must be at least 34.5, Gengaozo at least 35, and Sakura no Uta at most 31, because it is only stamina.
  - `ORDER` says which chart must be harder, by a margin, such as `thinkin bout u <3` over `White Eve`.
- **Results:** held-out Spearman 0.962 against MSD 17–31, MAE 0.81 MSD. It also keeps difficulty spreads in order (0.972) and orders the REFORM dans correctly (1.000).

### 7K: BMS level tables, without scratch

- **Reference:** three 7key1scratch tables from easiest to hardest: Starlight (sr1–sr12), Satellite (sl0–sl12) and Stella (st0–st12). They share one scale, because each table starts just above the previous one: sr1–12 are 1–12, sl0–12 are 13–25 and st0–12 are 26–38.
- **Scratch:** only table charts with less than 5% scratch notes count (121 Starlight, 550 Satellite, 741 Stella), and they are rated with the scratch removed.
- **Loss:** the mean Spearman inside each table and on the shared scale.
- **Results:** held-out Spearman 0.842 on Starlight, 0.963 on Satellite, 0.893 on Stella and 0.979 overall.
- **Limits:**
  - The tables were made for IIDX controllers. They can't show keyboard-specific difficulty such as brackets, where a pad player uses both hands but a keyboard player has all binds in one row.
  - Stella's upper levels are noisy: from about st6 up, ratings inside one level spread wider than the gap between levels.
  - Easy and hard tables pull the parameters in opposite directions.

### 14K2S: IIDX DP and DP tables

- **Reference:**
  - 5,091 IIDX DP charts (`chartmetas.format` iidx) with their official level 1–12.
  - DP Satellite: 209 of its charts are in the database.
  - DP Stella: only 19 of its charts are in the database.
- **Shared scale:** IIDX 1–12, then DP sl0–10 at 13–23, then DP st0–6 at 24–30. IIDX 12 is open-ended ("12 or harder"), so it only counts when ranking IIDX charts against each other.
- **Split:** charts are split into halves by file, so the difficulties of one song stay in the same half.
- **Results:** held-out Spearman 0.966 on IIDX, 0.960 on DP Satellite and 0.961 on the shared scale.
- **What it confirms:** IIDX 12 charts spread from about sl0 to sl4, and 94% of them rate at sl0 or above, as players expect.
- **Known miss:** charts with big scroll speed changes, like CHECKING YOU OUT or Fascination MAXX, are underrated, because the calculator doesn't read scroll speed.

## From raw rating to displayed number

Raw ratings have no meaning of their own, so each keymode maps them onto a scale. The mapping only changes the numbers, never the order inside a keymode.

### 4K: MSD scale

`user_diff = 0.6798 · raw + 6.786`, a linear fit of raw ratings against MSD on 17–31. Charts with raw 0 stay at 0.

### 7K: the dan curve onto the 4K scale

7K should show numbers that mean the same as 4K, but no chart is rated in both keymodes. The bridge is dan courses: pairs of 7K and 4K dans that players say feel about as hard.

| 7K Regular Dan | v2 7K raw | 4K REFORM dan | 4K rating |
|---|---|---|---|
| 0th | 24.71 | 2nd | 17.08 |
| 5th | 49.09 | 6th | 22.87 |
| 8th | 68.34 | 9th | 25.05 |
| Gamma | 94.05 | Beta | 27.76 |
| Zenith | 123.30 | Delta | 32.27 |

Both sides are rated from the `.osu` files. In the database, three of these charts have chart previews that decode 2–5% short, which gave wrong ratings.

No smooth two-parameter curve fits all five pairs: 4K Beta to Delta covers 4.5 points while 9th to Beta covers only 2.7, and the best fit (square root) still misses a pair by 0.77. Each pair is a deliberate player judgment, so the curve passes through all five exactly:

1. Take `x = ln(raw)`.
2. Find the two neighboring dans around `x` and interpolate linearly between their 4K ratings.
3. Below 0th dan and above Zenith, continue the line of the outermost segment.
4. Clamp at 0.

Because every segment rises, the curve keeps the 7K order. It maps sr1 to about 0, sl0 to 16.8, st0 to 25.0, st6 to 28.1 and st12 to 33.0.

The pairs live in `DANS_7K_TO_4K` in `calc/write_user_diff.py` and in `dans_7k_to_4k` in `rizucalc.lua`. They depend on both calculators, so rerate the dans whenever v2 4K, its MSD fit or v2 7K change.

### 14K2S: IIDX level scale

`user_diff = max(0, 1.2599 · √raw − 0.0218)`, a fit of level against √raw on the shared scale without IIDX 12. MAE is 0.76 levels. Most charts in the fit are IIDX charts, so the DP tables land below their nominal offsets: sl0 at about 11.8 and sl10 at about 19.2.

14K2S is not on the 4K scale yet. Lining it up would take dan pairs like the 7K ones.

## How to build or retune it

Run these from the repository root with the game closed. `calc/README.md` has the details of each tool.

1. **Decode charts.** `python3 -m calc.cache <inputmode>` decodes every chart of a keymode from `userdata/data.db` through `./luajit calc/worker.lua`, using the game's own decoder. It writes `calc/cache/<inputmode>.npz` and drops charts whose decoded length is more than 1% off.
2. **Get reference data.**
   - 4K uses stored MSD plus the targets in `calc/tune_4k.py`.
   - 7K uses the table JSON files in `calc/tables` (`sr`, `sl`, `st`).
   - 14K2S uses IIDX levels from `chartmetas` and `calc/tables/dpsl_*.json` and `dpst_*.json` from stellabms.xyz.
3. **Tune.** Run `python3 -m calc.tune_4k`, `calc.tune_7k` or `calc.tune_14k`, then copy the printed parameters into the calculator's `Params` defaults. If a value lands at the end of its search list, widen the list and run again.
4. **Self-check.** Run `python3 -m calc.v2_4k_test`, `calc.v2_7k_test` and `calc.v1_14k_test`.
5. **Rate the dans** after any 4K or 7K change, and update `DANS_7K_TO_4K`.
6. **Port to Lua.** Copy the parameters and mapping constants into `chart/scoring/rizucalc.lua`. Regenerate the expected values in `chart/scoring/rizucalc_test.lua` with the Python calculators, then run `./test chart/scoring/rizucalc_test.lua`. On 600 real charts, the Lua and Python versions agree to floating-point precision.
7. **Write ratings.** New chartdiffs get `user_diff` from the game itself through `chart/difficulty/UserDiffcalc.lua`. To fill an existing database from Python, run `python3 -m calc.write_user_diff <inputmode>`.

## Ideas not done yet

- **Keyboard targets for 7K:** add player-judged charts that feel 1–2 levels off on keyboard, like `ANCHORS` and `ORDER` for 4K. Brackets are the main case: three keys on the top row alternating with four on the bottom row.
- **Less weight for Stella:** count only Stella's coarse order above about st5, since its levels are noisy there.
- **14K2S on the 4K scale:** needs dan pairs like the 7K ones.
- **Scroll speed:** add a term for speed changes, which IIDX levels account for and the calculator ignores.
