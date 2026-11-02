-- Profanity filter for chat messages. Deliberately small: a handful of roots, one pass over
-- whole words. A word is lowercased, runs of the same letter collapse to one, then any root
-- inside it is replaced with `Profanity.mask`. Words starting with an allowlisted prefix are
-- left alone, which is how "рубля" survives while "блядь" does not.
local Profanity = {}

Profanity.mask = "***"

-- Roots, matched anywhere inside a word.
Profanity.words = {
	-- latin
	"nigg",
	"fuck",
	-- cyrillic
	"бля",
	"сук",
	-- chinese, full words only: single characters hit ordinary speech
	"操你",
	"他妈",
	"傻逼",
	"傻屄",
	"尼玛",
	"婊子",
	"贱人",
	"王八蛋",
	"狗日的",
	"滚你",
}

-- Words that legitimately contain a root above.
Profanity.allow = {
	"рубл", -- рубля
	"блях", -- бляха
	"сукн", -- сукно
	"суккуб",
}

local cyrillic_lower = {
	["А"] = "а", ["Б"] = "б", ["В"] = "в", ["Г"] = "г", ["Д"] = "д", ["Е"] = "е", ["Ё"] = "ё",
	["Ж"] = "ж", ["З"] = "з", ["И"] = "и", ["Й"] = "й", ["К"] = "к", ["Л"] = "л", ["М"] = "м",
	["Н"] = "н", ["О"] = "о", ["П"] = "п", ["Р"] = "р", ["С"] = "с", ["Т"] = "т", ["У"] = "у",
	["Ф"] = "ф", ["Х"] = "х", ["Ц"] = "ц", ["Ч"] = "ч", ["Ш"] = "ш", ["Щ"] = "щ", ["Ъ"] = "ъ",
	["Ы"] = "ы", ["Ь"] = "ь", ["Э"] = "э", ["Ю"] = "ю", ["Я"] = "я",
}

---Iterate UTF-8 characters of `text`.
local function chars(text)
	local i = 1
	return function()
		if i > #text then return nil end
		local b = text:byte(i)
		local len = 1
		if b >= 0xF0 then
			len = 4
		elseif b >= 0xE0 then
			len = 3
		elseif b >= 0xC0 then
			len = 2
		end
		local ch = text:sub(i, i + len - 1)
		i = i + len
		return ch
	end
end

---Lowercase one character. Lua 5.1 folds ASCII only, so Cyrillic needs a table.
---@param ch string
---@return string
local function lower(ch)
	local ascii = ch:lower()
	if #ascii == 1 then
		return ascii
	end
	return cyrillic_lower[ch] or ch
end

---@param ch string
---@return boolean
local function is_word_char(ch)
	if ch:match("^%w$") then return true end
	if ch:match("^[%z\1-\127]+$") then return false end
	-- Anything non-ASCII except whitespace and punctuation is treated as a letter.
	return true
end

---Split into words and lowercase each one.
---@param text string
---@return string[] words
local function words(text)
	local list = {}
	local current = {}
	for ch in chars(text) do
		if is_word_char(ch) then
			table.insert(current, lower(ch))
		elseif #current > 0 then
			table.insert(list, table.concat(current))
			current = {}
		end
	end
	if #current > 0 then
		table.insert(list, table.concat(current))
	end
	return list
end

---@param word string
---@return boolean
local function is_allowed(word)
	for _, prefix in ipairs(Profanity.allow) do
		if word:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

---@param word string
---@return boolean
local function is_dirty(word)
	if is_allowed(word) then return false end
	for _, root in ipairs(Profanity.words) do
		if word:find(root, 1, true) then
			return true
		end
	end
	return false
end

---@param text string
---@return boolean
function Profanity.contains(text)
	for _, word in ipairs(words(text)) do
		if is_dirty(word) then
			return true
		end
	end
	return false
end

---Replace every offending word with `Profanity.mask`.
---@param text string
---@return string
function Profanity.censor(text)
	local out = {}
	local raw = {}
	local normalized = {}
	for ch in chars(text) do
		if is_word_char(ch) then
			table.insert(raw, ch)
			table.insert(normalized, lower(ch))
		else
			if #raw > 0 then
				local word = table.concat(raw)
				table.insert(out, is_dirty(table.concat(normalized)) and Profanity.mask or word)
				raw = {}
				normalized = {}
			end
			table.insert(out, ch)
		end
	end
	if #raw > 0 then
		local word = table.concat(raw)
		table.insert(out, is_dirty(table.concat(normalized)) and Profanity.mask or word)
	end
	return table.concat(out)
end

return Profanity
