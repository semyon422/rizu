---@alias rizu.build.Target
---| "linux"
---| "windows"
---| "macos"

---@alias rizu.build.deps.StepKind
---| "archive"
---| "git"
---| "source-build"

---@class rizu.build.StatusRow
---@field name string
---@field value string

---@class rizu.build.deps.Action
---@field type string
---@field command? string
---@field compiler? string
---@field recursive? boolean
---@field dir? string
---@field src_dir? string
---@field build_dir? string
---@field script? string
---@field env? {[string]: string}
---@field url? string
---@field dest? string
---@field marker? string
---@field format? string
---@field strip_components? integer
---@field archive? string
---@field src? string
---@field dst? string
---@field path? string
---@field sources? string[]
---@field output? string
---@field cflags? string[]
---@field includes? string[]
---@field lib_dirs? string[]
---@field libs? string[]
---@field ldflags? string[]
---@field pattern? string
---@field args? string|string[]
---@field content? string
---@field inputs? string[]

---@class rizu.build.deps.Step
---@field id string
---@field kind rizu.build.deps.StepKind
---@field actions rizu.build.deps.Action[]
---@field outputs string[]
---@field inputs string[]
---@field status_label? string

---@class rizu.build.deps.Spec
---@field target? rizu.build.Target
---@field steps rizu.build.deps.Step[]
---@field outputs string[]

---@class rizu.build.deps.Env
---@field ctx rizu.build.Context
---@field target rizu.build.Target
---@field root_abs string
---@field bin_dir string
---@field downloads_dir string
---@field deps_dir string
---@field bin_dirs {[string]: string}

---@class rizu.build.deps.RunResult
---@field ok boolean
---@field exit_code integer
---@field step_id string
---@field command string
---@field stderr_hint string|nil

---@alias rizu.build.deps.ActionFunc fun(env: rizu.build.deps.Env, action: rizu.build.deps.Action): rizu.build.deps.RunResult

---@class rizu.build.deps.Actions: {[string]: rizu.build.deps.ActionFunc}

---@class rizu.build.Types
local Types = {}

return Types
