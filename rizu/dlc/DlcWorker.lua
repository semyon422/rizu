local class = require("class")
local MinoProvider = require("rizu.dlc.providers.MinoProvider")
local OsuFileProvider = require("rizu.dlc.providers.OsuFileProvider")
local EtternaPackProvider = require("rizu.dlc.providers.EtternaPackProvider")
local OsuDirectProvider = require("rizu.dlc.providers.OsuDirectProvider")
local BeatconnectProvider = require("rizu.dlc.providers.BeatconnectProvider")
local path_util = require("path_util")
local http_util = require("web.http.util")
local socket_url = require("socket.url")

---@class rizu.dlc.DlcWorker
---@operator call: rizu.dlc.DlcWorker
---@field request fun(url: string): {status: integer, body: string}?, string?
local DlcWorker = class()

---@param manager rizu.dlc.DlcManager
---@param workingDirectory string
---@param request? fun(url: string): {status: integer, body: string}?, string?
function DlcWorker:new(manager, workingDirectory, request)
	self.manager = manager
	self.workingDirectory = workingDirectory
	self.request = request or http_util.request
	self.providers = {
		mino = MinoProvider({request = self.request}),
		osu_file = OsuFileProvider(),
		etterna = EtternaPackProvider({request = self.request}),
		beatconnect = BeatconnectProvider({request = self.request}),
		akatsuki = OsuDirectProvider({
			baseUrl = "https://osu.ppy.sb",
			downloadUrl = "https://osu.ppy.sb/d/%s",
			request = self.request,
		}),
		ripple = OsuDirectProvider({
			baseUrl = "https://ripple.moe",
			downloadUrl = "https://ripple.moe/d/%s",
			request = self.request,
		}),
	}
end

---@param query string
---@param filters table?
---@param provider_name string?
---@return table[]? results, string? error
function DlcWorker:search(query, filters, provider_name)
	provider_name = provider_name or "mino"
	print("[DlcWorker] Search:", query, "Provider:", provider_name)
	local provider = self.providers[provider_name]
	if not provider then return nil, "Provider not found" end
	return provider:search(query, filters)
end

---@param url string
---@return love.ImageData? data, string? error
function DlcWorker:fetchThumbnail(url)
	local res, err = self.request(url)
	if not res then return nil, err end
	if res.status >= 400 then return nil, "HTTP " .. res.status end
	
	require("love.image")
	local ok, fileData = pcall(love.filesystem.newFileData, res.body, "thumb.jpg")
	if not ok then return nil, "FileData creation failed" end
	
	local ok2, imageData = pcall(love.image.newImageData, fileData)
	if not ok2 then return nil, "ImageData creation failed" end
	
	return imageData
end

---@param id string|number
---@param _type rizu.dlc.DlcType
---@param provider_name string?
---@param metadata table?
---@return boolean? success, string? error
function DlcWorker:download(id, _type, provider_name, metadata)
	provider_name = provider_name or "mino"
	local provider = self.providers[provider_name]
	if not provider then
		self.manager:updateTask(id, {status = "error", error = "Provider not found"})
		return nil, "Provider not found"
	end

	local url, err
	local mirror = metadata and metadata.mirror
	
	if mirror == "beatconnect" then
		url = "https://beatconnect.io/b/" .. id
	elseif mirror == "mino" then
		url = "https://catboy.best/d/" .. id
	else
		url, err = provider:getDownloadUrl(id)
	end

	if not url then
		self.manager:updateTask(id, {status = "error", error = err or "Failed to get download URL"})
		return nil, err
	end

	print("[DlcWorker] Downloading:", url)

	self.manager:updateTask(id, {status = "connecting", progress = 0})

	local client = http_util.client()
	local req, res, err = client:connect(url)
	if not req then
		print("[DlcWorker] Connection error:", err)
		self.manager:updateTask(id, {status = "error", error = err})
		return nil, err
	end

	local body_t = {}
	local total_received = 0
	local total_size = 0
	local start_time = love.timer.getTime()

	local ok, err = req:send("")
	if not ok then
		print("[DlcWorker] Request send error:", err)
		client:close()
		self.manager:updateTask(id, {status = "error", error = err})
		return nil, err
	end

	local ok, err = res:receive_headers()
	if not ok then
		print("[DlcWorker] Receive headers error:", err)
		client:close()
		self.manager:updateTask(id, {status = "error", error = err})
		return nil, err
	end

	if res.status >= 400 then
		local err_msg = "HTTP " .. res.status
		print("[DlcWorker] HTTP error:", res.status)
		client:close()
		self.manager:updateTask(id, {status = "error", error = err_msg})
		return nil, err_msg
	end

	total_size = tonumber(res.headers:get("Content-Length")) or 0
	self.manager:updateTask(id, {status = "downloading", size = total_size})

	local chunk_size = 64 * 1024
	while true do
		local chunk, err, partial = res:receive(chunk_size)
		if not chunk then
			if partial and #partial > 0 then
				total_received = total_received + #partial
				table.insert(body_t, partial)
			end

			if err == "closed" or err == nil then
				break
			end
			print("[DlcWorker] Receive chunk error for " .. tostring(id) .. ": " .. tostring(err))
			client:close()
			self.manager:updateTask(id, {status = "error", error = err})
			return nil, err
		end

		total_received = total_received + #chunk
		table.insert(body_t, chunk)

		local current_time = love.timer.getTime()
		local duration = current_time - start_time
		local speed = duration > 0 and (total_received / duration) or 0
		local progress = total_size > 0 and (total_received / total_size) or 0

		self.manager:updateTask(id, {
			progress = progress,
			total = total_received,
			speed = speed
		})
	end

	client:close()
	local body = table.concat(body_t)

	-- Determine filename
	local filename = url:match("^.+/(.-)$")
	local cd_header = res.headers:get("Content-Disposition")
	if cd_header then
		local cd = http_util.parse_content_disposition(cd_header)
		filename = cd.filename or filename
	end
	filename = socket_url.unescape(filename)
	filename = path_util.fix_illegal(filename)

	-- Save and extract
	self.manager:updateTask(id, {status = "extracting"})
	
	local success, extract_err = self:processDlc(id, _type, body, filename, metadata)
	if not success then
		print("[DlcWorker] Processing error for " .. tostring(id) .. ": " .. tostring(extract_err))
		self.manager:updateTask(id, {status = "error", error = extract_err})
		return nil, extract_err
	end

	self.manager:updateTask(id, {status = "completed", progress = 1})
	self.manager:onDlcCompleted(id, _type, metadata)

	return true
end

---@param id string|number
---@param _type rizu.dlc.DlcType
---@param data string
---@param filename string
---@param metadata table?
---@return boolean? success, string? error
function DlcWorker:processDlc(id, _type, data, filename, metadata)
	local fs = love.filesystem

	local base_dir = "userdata/charts/downloads"
	if _type == "pack" then
		base_dir = "userdata/charts/packs"
	elseif _type == "file" and metadata and metadata.dest_dir then
		base_dir = metadata.dest_dir
	end
	
	if not fs.getInfo(base_dir) then
		fs.createDirectory(base_dir)
	end

	local filepath = path_util.join(base_dir, filename)
	fs.write(filepath, data)

	if _type == "set" and filename:match("%.osz$") then
		local extract_dir = filename:match("^(.+)%.osz$")
		local extract_path = path_util.join(base_dir, extract_dir)
		
		local DlcExtractor = require("rizu.dlc.DlcExtractor")
		local ok, err = DlcExtractor.extract(filepath, extract_path)
		if not ok then
			return nil, "Extraction failed: " .. (err or "unknown error")
		end
		
		return true
	elseif _type == "pack" and filename:match("%.zip$") then
		local extract_dir = filename:match("^(.+)%.zip$")
		local extract_path = path_util.join(base_dir, extract_dir)
		
		local DlcExtractor = require("rizu.dlc.DlcExtractor")
		local ok, err = DlcExtractor.extract(filepath, extract_path)
		if not ok then
			return nil, "Extraction failed: " .. (err or "unknown error")
		end
		
		return true
	end

	return true
end

return DlcWorker
