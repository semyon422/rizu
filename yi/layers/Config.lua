local Layer = require("ui.Layer")
local Layout = require("ui.layout.Layout")
local Background = require("yi.views.config.Background")
local Title = require("yi.views.config.Title")

local Colors = require("yi.Colors")
local UIFactory = require("yi.UIFactory")
local UIConfigFactory = require("yi.UIConfigFactory")

---@class yi.Config : ui.Layer
---@operator call: yi.Config
local Config = Layer + {}

---@param ctx yi.Context
function Config:new(ctx)
	Layer.new(self)

	local res = ctx.resources
	local ui = UIFactory(ctx.resources)
	local conf = UIConfigFactory(ctx.resources)
	self.atlas, self.quads = ctx.resources.atlas, ctx.resources.quads

	self.layout = Layout({
		target_height = 1080,
		root = {children = {
			{padding = {100, 60, 100, 60}, align = {0.5, 0.5}, arrange = "col", children = {
				{id = "title", w = "100%", h = 150},
				{w = "100%", h = "*", arrange = "row", children = {
					{id = "tabs", w = 400, h = "100%"},
					{id = "content_bg", w = "*", h = "100%", padding = 5, children = {
						{id = "content"}
					}},
				}}
			}}
		}}
	})

	self:createTabs(ui, conf)

	self.background = Background(
		love.graphics.newImage("resources/yi/sky_background.jpg"),
		res:getFont("regular", 16)
	)

	self.title = Title(self.atlas, self.quads)
	self.title.box = self.layout:get("title")

	self.config_content = ui:List({
		box = self.layout:get("content"),
		width_percent = 1,
		height_percent = 1,
		gap = 32,
		padding = {40, 40, 40, 40},
	})

	self:addArray({
		self.background,
		self.title,
		ui:List({
			box = self.layout:get("tabs"),
			width_percent = 1,
			height_percent = 1,
			gap = 8,
			items = self.tab_buttons
		}),
		ui:Panel({
			box = self.layout:get("content_bg"),
			width_percent = 1,
			height_percent = 1,
			color = Colors.slate_900_80,
			border_color = Colors.white_40,
			corners = {true, false, true, false}
		}),
		self.config_content
	})

	self:setTab("general")
end

---@param name string
function Config:setTab(name)
	for _, v in pairs(self.tabs) do
		v.button:setActive(false)
	end

	if not self.tabs[name] then
		print("NO TAB", name)
		return
	end

	self.tabs[name].button:setActive(true)
	self.config_content:setItems(self.tabs[name].items)
end

---@param ui yi.UIFactory
---@param conf yi.UIConfigFactory
function Config:createTabs(ui, conf)
	self.tabs = {
		general = {
			button = ui:TabButton({
				text = "GENERAL",
				on_click = function() self:setTab("general") end
			}),
			items = {
			}
		},
		display = {
			button = ui:TabButton({
				text = "DISPLAY",
				on_click = function() self:setTab("display") end
			}),
			items = {
				conf:SectionLabel({text = "DISPLAY"}),
				conf:GroupLabel({text = "WINDOW"}),
				conf:Checkbox({text = "FULLSCREEN"}),
				conf:PanelSelect({
					text = "RESOLUTION",
					items = love.window.getFullscreenModes(),
					format_item = function(v)
						return ("%ix%i"):format(v.width, v.height)
					end
				}),
				conf:PanelSelect({
					text = "VSYNC",
					items = {"ENABLED", "ADAPTIVE", "DISABLED"}
				}),
				conf:Separator(),
				conf:GroupLabel({text = "FPS"}),
				conf:Checkbox({text = "UNLIMITED FPS"}),
				conf:Slider({
					text = "FPS LIMIT",
					min = 24,
					max = 1024,
					step = 1,
					value_format = "%i"
				}),
				conf:Separator(),
				conf:SectionLabel({text = "ADVANCED"}),
				conf:GroupLabel({text = "SLEEP"}),
				conf:PanelSelect({
					text = "SLEEP FUNCTION",
					items = {"NANOSLEEP", "LOVE", "WINAPI"}
				}),
				conf:Slider({
					text = "FPS LIMITER BUSY LOOP RATIO",
					step = 0.01,
					min = 0,
					max = 1
				})
			}
		}
	}

	self.tab_buttons = {
		self.tabs.general.button,
		self.tabs.display.button,
	}
end

return Config
