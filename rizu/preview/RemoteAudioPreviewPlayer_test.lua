local RemoteAudioPreviewPlayer = require("rizu.preview.RemoteAudioPreviewPlayer")

local test = {}

local function createPlayer()
	local decoder = {released = 0}
	function decoder:release() self.released = self.released + 1 end

	local source = {paused = 0, released = 0, updated = 0, played = 0}
	function source:pause() self.paused = self.paused + 1 end
	function source:release() self.released = self.released + 1 end
	function source:update() self.updated = self.updated + 1 end
	function source:play() self.played = self.played + 1 end
	function source:setVolume(volume) self.volume = volume end

	local provider = {}
	function provider:createDecoder(data)
		decoder.data = data
		return decoder
	end
	function provider:createChartSource(value, use_tempo)
		source.decoder = value
		source.use_tempo = use_tempo
		return source
	end

	local settings = {values = {master = 0.5, music = 0.4}}
	function settings:getNumber(key)
		if key:find("master", 1, true) then return self.values.master end
		return self.values.music
	end
	return RemoteAudioPreviewPlayer(settings, provider), decoder, source, settings
end

---@param t testing.T
function test.loads_updates_and_releases_audio(t)
	local player, decoder, source, settings = createPlayer()
	t:assert(player:load("webm bytes"))
	t:eq(decoder.data, "webm bytes")
	t:eq(source.decoder, decoder)
	t:eq(source.use_tempo, false)
	t:eq(source.volume, 0.2)
	t:eq(source.played, 1)
	t:eq(source.updated, 1)

	settings.values.music = 0.2
	player:update()
	t:eq(source.volume, 0.1)
	t:eq(source.updated, 2)

	player:stop()
	t:eq(source.paused, 1)
	t:eq(source.released, 1)
	t:eq(decoder.released, 1)
	player:stop()
	t:eq(source.released, 1)
end

---@param t testing.T
function test.releases_decoder_when_source_creation_fails(t)
	local player, decoder = createPlayer()
	function player.provider:createChartSource()
		error("source failed")
	end
	local ok, err = player:load("webm bytes")
	t:eq(ok, nil)
	t:assert(err:find("source failed", 1, true))
	t:eq(decoder.released, 1)
end

return test
