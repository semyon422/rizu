---@class rizu.select.SelectionChangedEvent
---@field type "selection_changed"
---@field level integer
---@field index integer
---@field id integer?

---@class rizu.select.ChartplaySelectionChangedEvent
---@field type "chartplay_selection_changed"
---@field index integer
---@field chartplay_id integer?

---@class rizu.select.ChartviewChangedEvent
---@field type "chartview_changed"
---@field chartview rizu.library.LocatedChartview?

---@class rizu.select.PrimaryItemsUpdatedEvent
---@field type "primary_items_updated"

---@class rizu.select.ChartmetaFoundEvent
---@field type "chartmeta_found"
---@field hash string
---@field index integer

---@class rizu.select.SelectedSetChangedEvent
---@field type "selected_set_changed"

---@class rizu.select.LevelScrolledEvent
---@field type "level_scrolled"
---@field level integer
---@field chartview rizu.library.LocatedChartview

---@class rizu.select.ChartplayScrolledEvent
---@field type "chartplay_scrolled"
---@field chartplay sea.Chartplay

---@class rizu.select.CollectionSelectionChangedEvent
---@field type "collection_selection_changed"
---@field item rizu.library.Collections.TreeNode?
---@field query_scope_changed boolean

---@class rizu.select.ListStoreCountChangedEvent
---@field type "list_count_changed"
---@field count integer

---@class rizu.select.ListStoreItemLoadedEvent
---@field type "list_item_loaded"
---@field index integer
---@field item rizu.library.LocatedChartview

---@class rizu.select.ScoreStoreItemsChangedEvent
---@field type "score_items_changed"
---@field items sea.Chartplay[]

---@class rizu.select.CollectionStoreTreeChangedEvent
---@field type "collection_tree_changed"
---@field tree rizu.library.Collections.TreeNode

---@alias rizu.select.SelectionStateEvent
---| rizu.select.SelectionChangedEvent
---| rizu.select.ChartplaySelectionChangedEvent

---@alias rizu.select.ChartSelectorEvent
---| rizu.select.ChartviewChangedEvent
---| rizu.select.PrimaryItemsUpdatedEvent
---| rizu.select.ChartmetaFoundEvent
---| rizu.select.SelectedSetChangedEvent
---| rizu.select.LevelScrolledEvent

---@alias rizu.select.ScoreSelectorEvent
---| rizu.select.ChartplayScrolledEvent
---| rizu.select.ScoreStoreItemsChangedEvent

---@alias rizu.select.CollectionSelectorEvent
---| rizu.select.CollectionSelectionChangedEvent

---@alias rizu.select.ListStoreEvent
---| rizu.select.ListStoreCountChangedEvent
---| rizu.select.ListStoreItemLoadedEvent

---@alias rizu.select.ScoreStoreEvent
---| rizu.select.ScoreStoreItemsChangedEvent

---@alias rizu.select.CollectionStoreEvent
---| rizu.select.CollectionStoreTreeChangedEvent

---@alias rizu.select.Event
---| rizu.select.SelectionStateEvent
---| rizu.select.ChartSelectorEvent
---| rizu.select.ScoreSelectorEvent
---| rizu.select.CollectionSelectorEvent
---| rizu.select.ListStoreEvent
---| rizu.select.ScoreStoreEvent
---| rizu.select.CollectionStoreEvent

---@alias rizu.select.SelectionStateEventReceiver fun(event: rizu.select.SelectionStateEvent)
---@alias rizu.select.SelectionStateEventObserver {receive: fun(self: table, event: rizu.select.SelectionStateEvent)}

---@alias rizu.select.ChartSelectorEventReceiver fun(event: rizu.select.ChartSelectorEvent)
---@alias rizu.select.ChartSelectorEventObserver {receive: fun(self: table, event: rizu.select.ChartSelectorEvent)}

---@alias rizu.select.ScoreSelectorEventReceiver fun(event: rizu.select.ScoreSelectorEvent)
---@alias rizu.select.ScoreSelectorEventObserver {receive: fun(self: table, event: rizu.select.ScoreSelectorEvent)}

---@alias rizu.select.CollectionSelectorEventReceiver fun(event: rizu.select.CollectionSelectorEvent)
---@alias rizu.select.CollectionSelectorEventObserver {receive: fun(self: table, event: rizu.select.CollectionSelectorEvent)}

---@alias rizu.select.ListStoreEventReceiver fun(event: rizu.select.ListStoreEvent)
---@alias rizu.select.ListStoreEventObserver {receive: fun(self: table, event: rizu.select.ListStoreEvent)}

---@alias rizu.select.ScoreStoreEventReceiver fun(event: rizu.select.ScoreStoreEvent)
---@alias rizu.select.ScoreStoreEventObserver {receive: fun(self: table, event: rizu.select.ScoreStoreEvent)}

---@alias rizu.select.CollectionStoreEventReceiver fun(event: rizu.select.CollectionStoreEvent)
---@alias rizu.select.CollectionStoreEventObserver {receive: fun(self: table, event: rizu.select.CollectionStoreEvent)}

return {}
