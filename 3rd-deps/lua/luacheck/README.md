# Vendored Luacheck parser

This directory contains the parser-only dependency used by `deco.lua`.

- Upstream: https://github.com/lunarmodules/luacheck
- Version: 1.2.0
- Commit: `cc089e3f65acdd1ef8716cc73a3eca24a6b845e4`
- License: MIT, reproduced in `LICENSE`

The vendored lexer has one local compatibility patch: support for LuaJIT binary numerals such as `0b10000000`. All other files are copied from the pinned upstream commit.
