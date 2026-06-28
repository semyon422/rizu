---@class rizu.select.SelectionEvent
---@field type "selection"
---@field level integer
---@field index integer
---@field id integer?

---@class rizu.select.ScoreEvent
---@field type "score"
---@field index integer
---@field id integer?

---@class rizu.select.ChartviewEvent
---@field type "chartview"
---@field chartview rizu.library.LocatedChartview?

---@class rizu.select.UpdatePrimaryItemsEvent
---@field type "update_primary_items"

---@class rizu.select.FindNotechartEvent
---@field type "find_notechart"
---@field hash string
---@field index integer

---@class rizu.select.SetChangedEvent
---@field type "set_changed"

---@class rizu.select.ScrollLevelEvent
---@field type "scroll_level"
---@field level integer
---@field chartview rizu.library.LocatedChartview

---@class rizu.select.ScrollScoreEvent
---@field type "scroll_score"
---@field chartplay sea.Chartplay

---@class rizu.select.CollectionChangedEvent
---@field type "collection_changed"
---@field item table?
---@field path_changed boolean

---@class rizu.select.ListStoreCountEvent
---@field type "count"
---@field count integer

---@class rizu.select.ListStoreItemLoadedEvent
---@field type "item_loaded"
---@field index integer
---@field item rizu.library.LocatedChartview

---@class rizu.select.ScoreStoreItemsEvent
---@field type "items"
---@field items sea.Chartplay[]

---@class rizu.select.CollectionStoreTreeEvent
---@field type "tree"
---@field tree table

---@alias rizu.select.SelectionStateEvent
---| rizu.select.SelectionEvent
---| rizu.select.ScoreEvent

---@alias rizu.select.ChartSelectorEvent
---| rizu.select.ChartviewEvent
---| rizu.select.UpdatePrimaryItemsEvent
---| rizu.select.FindNotechartEvent
---| rizu.select.SetChangedEvent
---| rizu.select.ScrollLevelEvent

---@alias rizu.select.ScoreSelectorEvent
---| rizu.select.ScrollScoreEvent

---@alias rizu.select.CollectionSelectorEvent
---| rizu.select.CollectionChangedEvent

---@alias rizu.select.ListStoreEvent
---| rizu.select.ListStoreCountEvent
---| rizu.select.ListStoreItemLoadedEvent

---@alias rizu.select.ScoreStoreEvent
---| rizu.select.ScoreStoreItemsEvent

---@alias rizu.select.CollectionStoreEvent
---| rizu.select.CollectionStoreTreeEvent

---@alias rizu.select.Event
---| rizu.select.SelectionStateEvent
---| rizu.select.ChartSelectorEvent
---| rizu.select.ScoreSelectorEvent
---| rizu.select.CollectionSelectorEvent
---| rizu.select.ListStoreEvent
---| rizu.select.ScoreStoreEvent
---| rizu.select.CollectionStoreEvent

return {}
