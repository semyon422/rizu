local Layer = require("yi.Layer")
local Title = require("yi.views.Title")

local Colors = require("yi.Colors")
local UIFactory = require("yi.UIFactory")
local UIConfigFactory = require("yi.UIConfigFactory")

local composition = require("ui.composition")
local Stack, Horizontal, Vertical = composition.Stack, composition.Horizontal, composition.Vertical

---@class yi.Config : yi.Layer
---@operator call: yi.Config
local Config = Layer + {}

---@param yi yi.UserInterface
function Config:new(yi)
	Layer.new(self)
	self.yi = yi

	local ui = UIFactory(yi.resources)
	local conf = UIConfigFactory(yi.resources)
	self.canvas = love.graphics.newCanvas(love.graphics.getDimensions())
	self.atlas, self.quads = yi.resources.atlas, yi.resources.quads

	self:createTabs(ui, conf)

	self.title = Title(self.atlas, self.quads)

	self.config_content = ui:List({
		width_percent = 1,
		height_percent = 1,
		gap = 32,
		padding = {40, 40, 40, 40},
	})

	self.tabs_list = ui:List({
		width_percent = 1,
		height_percent = 1,
		gap = 8,
		items = self.tab_buttons
	})

	self.content_bg = ui:Panel({
		width_percent = 1,
		height_percent = 1,
		color = Colors.slate_900_80,
		border_color = Colors.white_40,
		corners = {true, false, true, false}
	})

	self.composition_root = Stack({
		Vertical({
			w = "100%",
			h = "100%",
			padding = {100, 60, 100, 60},
			gap = 20,
			Stack({
				h = 120,
				self.title,
			}),
			Horizontal({
				w = "*",
				h = "*",
				gap = 20,
				Stack({
					w = 400,
					h = "100%",
					self.tabs_list,
				}),
				Stack({
					w = "*",
					h = "100%",
					self.content_bg,
					composition.Stack({
						w = "100%",
						h = "100%",
						padding = 5,
						self.config_content,
					}),
				}),
			}),
		}),
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

function Config:draw()
	local a = self.transition:get()

	love.graphics.setCanvas(self.canvas)
	love.graphics.clear()
	love.graphics.setBlendMode("alpha", "alphamultiply")
	Layer.draw(self)
	love.graphics.setCanvas()

	love.graphics.setColor(a, a, a, a)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(self.canvas)
	love.graphics.setBlendMode("alpha")
end

function Config:handleKeyDown(key)
	if key == "escape" then
		self.yi:transitTo(self.yi.previous_layer or self.yi.main_menu)
	end
end

return Config
