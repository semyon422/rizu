# Bundled Needle Model

`needle-q8-stripped.bin` is the int8 stripped runtime export used by the in-game Needle command palette.

- Runtime format: `NDLRTM1`
- SHA-256: `3faa3c16dbb3bb34bba516b56e12d263f1a77c1dd7baa29f169234705808d60f`
- Source project: the Needle runtime imported under `aqua/ai/needle`

The model is loaded only by the managed Needle inference worker and includes its `NDLTOK1` tokenizer block.
