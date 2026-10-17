local ComputeVersion = {}

ComputeVersion.development = "development"

---@return string
function ComputeVersion.current()
	return os.getenv("RIZU_COMPUTE_VERSION") or ComputeVersion.development
end

return ComputeVersion
