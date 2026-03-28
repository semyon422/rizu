---@alias build.Target
---| "linux"
---| "windows"
---| "macos"

---@alias build.deps_dsl.StepKind
---| "archive"
---| "git"
---| "source-build"
---| "modules"
---| "sync"
---| "package-hooks"

---@class build.StatusRow
---@field name string
---@field value string

---@class build.deps_dsl.Action
---@field type string
---@field command? string
---@field dir? string
---@field stderr_hint? string
---@field url? string
---@field dest? string
---@field format? string
---@field archive? string
---@field src? string
---@field dst? string
---@field path? string
---@field pattern? string
---@field out_file? string
---@field args? string
---@field tool? string
---@field target? string
---@field from? string
---@field to? string
---@field mode? string

---@class build.deps_dsl.Step
---@field id string
---@field kind build.deps_dsl.StepKind
---@field actions build.deps_dsl.Action[]
---@field outputs string[]
---@field requires string[]
---@field status_label? string
---@field skip_if_exists_all? string[]

---@class build.deps_dsl.Spec
---@field target? build.Target
---@field steps build.deps_dsl.Step[]
---@field outputs string[]

---@class build.deps_dsl.Env
---@field ctx build.Context
---@field target build.Target
---@field root_abs string
---@field bin_dir string
---@field downloads_dir string
---@field deps_dir string
---@field bin_dirs table<string, string>

---@class build.deps_dsl.RunResult
---@field ok boolean
---@field exit_code integer
---@field step_id string
---@field command string
---@field stderr_hint string|nil

local Types = {}

return Types
