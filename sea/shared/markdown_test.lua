local markdown = require("sea.shared.markdown")

local test = {}

---@param t testing.T
function test.inline(t)
	t:eq(markdown.to_html("**a** and *b* `*c*` [**d**](https://e.f/?g=1&h=2)"),
		'<p><strong>a</strong> and <em>b</em> <code>*c*</code> <a href="https://e.f/?g=1&amp;h=2"><strong>d</strong></a></p>\n')
end

---@param t testing.T
function test.stars_spam(t)
	t:eq(markdown.to_html("*********"), "<hr>\n")
	t:eq(markdown.to_html("a ********* b ** c * d"), "<p>a ********* b ** c * d</p>\n")
	t:eq(markdown.to_html("2 * 3 * 4 and **x**"), "<p>2 * 3 * 4 and <strong>x</strong></p>\n")
end

---@param t testing.T
function test.escape(t)
	t:eq(markdown.to_html("<script> &amp; & \"q\""), "<p>&lt;script&gt; &amp; &amp; &quot;q&quot;</p>\n")
end

---@param t testing.T
function test.blocks(t)
	t:eq(markdown.to_html("## Head ##\ntext  \nmore  \n\n> quote\n\n```\n<b>\n```\n___"), table.concat({
		"<h2>Head</h2>",
		"<p>text<br>\nmore</p>",
		"<blockquote>\n<p>quote</p>\n</blockquote>",
		"<pre><code>&lt;b&gt;</code></pre>",
		"<hr>",
		"",
	}, "\n"))
end

---@param t testing.T
function test.lists(t)
	t:eq(markdown.to_html("1. a\n\t* b\n\t* c\n\n2. d\n\n3. e\ntext"), table.concat({
		"<ol>",
		"<li>a\n<ul>\n<li>b</li>\n<li>c</li>\n</ul>\n</li>",
		"<li>d</li>",
		"<li>e</li>",
		"</ol>",
		"<p>text</p>",
		"",
	}, "\n"))
	t:eq(markdown.to_html("3. a\n- b"), '<ol start="3">\n<li>a</li>\n</ol>\n<ul>\n<li>b</li>\n</ul>\n')
end

return test
