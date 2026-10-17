---@param user sea.User
---@param url? string
---@return string
return function (user, url)
	local attrs = ""

	if user.enable_gradient then
		attrs = attrs .. ([[class="text-clip" style="background: linear-gradient(90deg, %s, %s)" ]]):format(
			("#%06x"):format(user.color_left),
			("#%06x"):format(user.color_right)
		)
	elseif not user.enable_gradient and url then
		attrs = attrs .. [[class="has-text-primary-35"]]
	end

	local online_dot = user.online and [[<span class="user-online-dot" title="Online"></span>]] or ""
	local name_html = ([[<strong>%s</strong>]]):format(user.name)

	local content = ""
	if url then
		content = ([[<a href="%s" %s>%s</a>]]):format(url, attrs, name_html)
	else
		content = ([[<span %s>%s</span>]]):format(attrs, name_html)
	end

	return ([[<span style="display: inline-flex; align-items: center; vertical-align: middle;">%s%s</span>]]):format(content, online_dot)
end
