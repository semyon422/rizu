--- Subquery model for case-insensitive user name lookups.
---
--- SQLite doesn't support case-insensitive collation by default on TEXT.
--- This model wraps the users table with a COLLATE NOCASE condition
--- so that `:find({name = "SomeName"})` works case-insensitively.

---@type rdb.ModelOptions
return {
	subquery = [[
		SELECT * FROM users
	]],
	types = {
		is_restricted = "boolean",
		is_bot = "boolean",
	},
}
