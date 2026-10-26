# osu!mania ScoreV1: differences from osu!stable

`rizu/engine/ScoreEngine/scores/OsuManiaV1Score.lua` compared with the osu!stable source
(`Ruleset.IncreaseScoreHit`, `HitCircleManiaLong`, `HitObjectManagerMania`, `RulesetMania_HpCalculation`).

## Matches stable

- Hit windows: 16 ms for 300g, then 64 / 97 / 127 / 151 / 188 ms minus 3·OD.
- LN judgement: head x1.2 / x1.1 and total x2.4 / x2.2 for 300g / 300, x2 for 200 / 100, a hold break caps at 200,
  a release before the 50 window is a miss.
- Score: 500000/N scaling, values 320/300/200/100/50, bonus deltas 32/32/16/8/4, `sqrt(bonus)` term,
  bonus meter -44/-24/-8/+1/+2 (50/100/200/300/300g), miss empties the meter, restore to 100 at each 384 combo.
- A hold break resets combo at once.
- HP per judgement and the HP multiplier simulation (`CalculateHpDropRate`).

## Known differences

| Area | Stable | Ours | Why |
|---|---|---|---|
| Final score | `Math.Round` at the end, 999999 becomes 1000000 | floor of the running sum | Not handled at the end of a play. |
| Score mods | Miss/50/100/200 bonus penalties are divided by the score-increase mod multiplier | no mod multiplier | Mods are not applied. Same without such mods. |
| Hold ticks | Every 100 ms of an LN hold: +1 combo and `0.5 - hp*0.05` HP | not modelled | The score only sees note state changes, no hold-time events. Combo and HP differ slightly on LN-heavy charts. |
| HP simulation pre-roll | Drain starts one `PreEmpt` before the first note, `PreEmpt = max(TimeAt(hitposition), LongestTime) + 200` depends on scroll speed | fixed 1000 ms | Scroll speed is unknown to the score system. Shifts the HP multiplier slightly. |
| HP simulation breaks | Drain skips chart breaks | breaks ignored | The score system does not know the breaks. |
| HP mods | EZ / HR (HP drain rate), HT (drain rate x0.75), DT window scaling | not applied | Mods are not applied. |
| HP passive drain | computed, never applied in mania | none | Same behavior. |

## Notes

- `hp` is the chart's HPDrainRate (`healths.data / 10`), 5 when the chart has none.
- Health is kept on stable's 0..200 scale internally and reported as 0..100.
