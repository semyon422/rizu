## Goal

Provide a built-in final fallback for missing Aim slider tick samples.

## User Experience

Chart samples and user hitsounds retain priority. Missing slider ticks use `aim-slidertick.wav`, a short synthetic click, rather than disappearing silently.

## Asset Provenance

`hitsounds/aim-slidertick.wav` is newly synthesized project audio, not copied from osu! or a skin. Mono PCM16, 44100 Hz, 2205 samples (50 ms). Sample i is rounded from:

`10000 * exp(-i / 350) * sin(2 * pi * 1800 * i / 44100) * min(1, i / 30)`

It is distributed under the repository's license.
