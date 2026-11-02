local Profanity = require("sea.chat.Profanity")

local test = {}

---@param t testing.T
function test.keeps_clean_messages(t)
	t:eq(Profanity.contains("привет, как дела?"), false)
	t:eq(Profanity.censor("привет, как дела?"), "привет, как дела?")
	t:eq(Profanity.contains("gg wp, new top play"), false)
	t:eq(Profanity.contains("操作 верная"), false)
end

---@param t testing.T
function test.masks_asked_words(t)
	t:eq(Profanity.censor("what the fuck"), "what the ***")
	t:eq(Profanity.contains("nigger"), true)
	t:eq(Profanity.censor("NIGGER!"), "***!")
	t:eq(Profanity.censor("блядь опять"), "*** опять")
	t:eq(Profanity.censor("сука, ну"), "***, ну")
	t:eq(Profanity.contains("fucked up"), true)
	t:eq(Profanity.contains("блядина"), true)
end

---@param t testing.T
function test.masks_chinese(t)
	t:eq(Profanity.censor("操你妈"), "***")
	t:eq(Profanity.contains("傻逼"), true)
	t:eq(Profanity.contains("他妈的"), true)
end

---@param t testing.T
function test.spares_words_that_only_look_like_mat(t)
	t:eq(Profanity.contains("рубля два"), false)
	t:eq(Profanity.contains("бляха на ремне"), false)
	t:eq(Profanity.contains("сукно и суккуб"), false)
	t:eq(Profanity.contains("класс и мандат"), false)
end

return test