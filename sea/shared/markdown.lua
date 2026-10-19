-- Minimal markdown to HTML for our own trusted pages (wiki, policies).
-- Blocks: # headings, ``` fences, > quotes, -/*/+ and 1. lists (nested by indent), ---/***/___ rules, paragraphs.
-- Inline: `code`, [text](url), **bold**, *em*, two trailing spaces for <br>.
-- Anything else is plain text. Raw HTML is escaped, existing entities are kept.

local markdown = {}

local escapes = {["<"] = "&lt;", [">"] = "&gt;", ['"'] = "&quot;"}

---@param s string
---@return string
local function escape(s)
	s = s:gsub("&(#?%w*;?)", function(e)
		if #e > 1 and e:sub(-1) == ";" then
			return "&" .. e
		end
		return "&amp;" .. e
	end)
	return (s:gsub('[<>"]', escapes))
end

---@param s string
---@return string
local function inline(s)
	local held = {}
	local function hold(html)
		table.insert(held, html)
		return "\1" .. #held .. "\2"
	end

	s = escape(s)
	s = s:gsub("`([^`]+)`", function(code)
		return hold("<code>" .. code .. "</code>")
	end)
	s = s:gsub("%[([^%]]+)%]%(([^%s)]+)%)", function(text, url)
		return hold(('<a href="%s">'):format(url)) .. text .. hold("</a>")
	end)
	-- The content must start and end with a non-space, non-* char, so runs like ***** stay as is
	s = s:gsub("%*%*([^%s*].-)%*%*", function(text)
		if not text:find("[%s*]$") then
			return "<strong>" .. text .. "</strong>"
		end
	end)
	s = s:gsub("%*([^%s*][^*]-)%*", function(text)
		if not text:find("%s$") then
			return "<em>" .. text .. "</em>"
		end
	end)

	return (s:gsub("\1(%d+)\2", function(i)
		return held[tonumber(i)]
	end))
end

---@param line string
---@return "ul"|"ol"?
---@return string?
---@return string?
local function list_item(line)
	local text = line:match("^[-*+]%s+(.*)$")
	if text then
		return "ul", text
	end
	local n, ol_text = line:match("^(%d+)%.%s+(.*)$")
	if n then
		return "ol", ol_text, n
	end
end

---@param line string
---@return boolean
local function is_rule(line)
	local trimmed = line:match("^%s*(.-)%s*$") ---@type string
	local c = trimmed:sub(1, 1)
	return #trimmed >= 3 and (c == "-" or c == "*" or c == "_") and trimmed == c:rep(#trimmed)
end

---@param line string
---@return boolean
local function starts_block(line)
	return line:find("^%s*```") ~= nil or line:find("^#+%s") ~= nil or line:find("^>") ~= nil or
		is_rule(line) or list_item(line) ~= nil
end

---@param line string
---@return boolean
local function is_blank(line)
	return not line:find("%S")
end

---@param lines string[]
---@return string[]
local function dedent(lines)
	local indent = ""
	for _, line in ipairs(lines) do
		if not is_blank(line) then
			indent = line:match("^[ \t]*")
			break
		end
	end
	---@type string[]
	local out = {}
	for i, line in ipairs(lines) do
		if line:sub(1, #indent) == indent then
			out[i] = line:sub(#indent + 1)
		else
			out[i] = line:match("^[ \t]*(.*)$")
		end
	end
	return out
end

local parse

---@param lines string[]
---@param i integer
---@param out string[]
---@return integer
local function parse_list(lines, i, out)
	local kind, _, start = list_item(lines[i])
	if start and start ~= "1" then
		table.insert(out, ('<ol start="%s">'):format(start))
	else
		table.insert(out, "<" .. kind .. ">")
	end

	while lines[i] do
		local item_kind, text = list_item(lines[i])
		if item_kind ~= kind then
			break
		end
		i = i + 1

		local children = {}
		while lines[i] do
			local line = lines[i]
			if line:find("^[ \t]") and not is_blank(line) then
				table.insert(children, line)
				i = i + 1 ---@type integer
			elseif is_blank(line) then
				local j = i ---@type integer
				while lines[j] and is_blank(lines[j]) do
					j = j + 1
				end
				if not (lines[j] and lines[j]:find("^[ \t]")) then
					break
				end
				i = j
			else
				break
			end
		end

		---@cast text string
		if #children == 0 then
			table.insert(out, "<li>" .. inline(text) .. "</li>")
		else
			table.insert(out, "<li>" .. inline(text) .. "\n" .. parse(dedent(children)) .. "</li>")
		end

		-- A blank line between items of the same list keeps the list going
		local j = i ---@type integer
		while lines[j] and is_blank(lines[j]) do
			j = j + 1
		end
		if lines[j] and list_item(lines[j]) == kind then
			i = j
		end
	end

	table.insert(out, "</" .. kind .. ">")
	return i
end

---@param lines string[]
---@return string
function parse(lines)
	local out = {}
	local i = 1
	while lines[i] do
		local line = lines[i]
		if is_blank(line) then
			i = i + 1
		elseif line:find("^%s*```") then
			local code = {}
			i = i + 1
			while lines[i] and not lines[i]:find("^%s*```") do
				table.insert(code, lines[i])
				i = i + 1
			end
			i = i + 1
			table.insert(out, "<pre><code>" .. escape(table.concat(code, "\n")) .. "</code></pre>")
		elseif line:find("^#+%s") and #line:match("^#+") <= 6 then
			local hashes, text = line:match("^(#+)%s+(.-)[%s#]*$")
			table.insert(out, ("<h%d>%s</h%d>"):format(#hashes, inline(text), #hashes))
			i = i + 1
		elseif is_rule(line) then
			table.insert(out, "<hr>")
			i = i + 1
		elseif line:find("^>") then
			local quote = {}
			while lines[i] and lines[i]:find("^>") do
				table.insert(quote, (lines[i]:gsub("^> ?", "")))
				i = i + 1
			end
			table.insert(out, "<blockquote>\n" .. parse(quote) .. "</blockquote>")
		elseif list_item(line) then
			i = parse_list(lines, i, out)
		else
			local para = {}
			while lines[i] and not is_blank(lines[i]) and (#para == 0 or not starts_block(lines[i])) do
				local l = lines[i]
				local text = inline(l:match("^%s*(.-)%s*$"))
				if l:find("  $") then
					text = text .. "<br>"
				end
				table.insert(para, text)
				i = i + 1
			end
			para[#para] = para[#para]:gsub("<br>$", "") ---@type string
			table.insert(out, "<p>" .. table.concat(para, "\n") .. "</p>")
		end
	end
	return table.concat(out, "\n") .. "\n"
end

---@param s string
---@return string
function markdown.to_html(s)
	local lines = {}
	for line in (s:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do
		table.insert(lines, line)
	end
	return parse(lines)
end

return markdown
