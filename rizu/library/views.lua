---@class rizu.library.LocationInsert
---@field id integer?
---@field path string
---@field name string
---@field is_relative boolean
---@field is_internal boolean

---@class rizu.library.Location: rizu.library.LocationInsert
---@field id integer

---@class rizu.library.ChartviewIds
---@field chartfile_id integer
---@field chartfile_set_id integer
---@field chartmeta_id integer
---@field chartdiff_id integer
---@field chartplay_id integer

---@class rizu.library.IChartviewBase: rizu.library.ChartviewIds
---@field lamp boolean?

---@class rizu.library.LocatedChartfile: sea.ClientChartfile
---@field chartmeta_id integer?
---@field location_id integer
---@field set_is_file boolean
---@field set_dir string?
---@field set_name string
---@field chartfile_name string
---@field dir string -- computed
---@field path string -- computed

---@class rizu.library.ChartmetaDiffsMissing
---@field id integer
---@field hash string
---@field index integer

---@class rizu.library.ChartviewSetFields
---@field location_id integer
---@field set_is_file boolean
---@field set_dir string?
---@field set_name string
---@field set_modified_at integer

---@class rizu.library.ChartviewFileFields
---@field chartfile_name string
---@field modified_at integer
---@field hash string

---@class rizu.library.ChartviewPlayStatFields
---@field accuracy number?
---@field miss_count integer?
---@field chartplay_created_at integer?

---@class rizu.library.ChartviewMetaFields
---@field index integer
---@field inputmode string
---@field format sea.ChartFormat
---@field chartmeta_timings sea.Timings?
---@field chartmeta_healths sea.Healths?
---@field title string?
---@field title_unicode string?
---@field artist string?
---@field artist_unicode string?
---@field name string?
---@field creator string?
---@field level number?
---@field source string?
---@field tags string?
---@field audio_path string?
---@field audio_offset number?
---@field background_path string?
---@field preview_time number?
---@field osu_beatmap_id integer?
---@field osu_beatmapset_id integer?
---@field tempo number?
---@field tempo_avg number?
---@field tempo_max number?
---@field tempo_min number?

---@class rizu.library.ChartviewMetaUserDataFields
---@field chartmeta_local_offset number?
---@field chartmeta_rating number?
---@field chartmeta_comment string?

---@class rizu.library.ChartviewDiffFields
---@field modifiers sea.Modifier[]
---@field rate number
---@field mode sea.Gamemode
---@field chartdiff_inputmode string
---@field duration number
---@field start_time number
---@field notes_count integer
---@field judges_count integer
---@field long_notes_ratio number
---@field note_types_count {[chart.NoteType]: integer}
---@field density_data number[]
---@field sv_data number[]
---@field enps_diff number
---@field osu_diff number
---@field msd_diff number
---@field msd_diff_data minacalc.Ssr
---@field msd_diff_rates number[]
---@field user_diff number
---@field user_diff_data string

---@class rizu.library.ChartviewDiffPreviewFields
---@field notes_preview string

---@class rizu.library.ChartviewRepoComputedFields
---@field dir string -- computed
---@field path string -- computed
---@field difficulty number? -- added by repo as alias
---@field lamp boolean? -- added by repo
---@field difftable_chartmetas sea.DifftableChartmeta[]? -- enriched by repo

---@class rizu.library.Chartview: rizu.library.IChartviewBase, rizu.library.ChartviewSetFields, rizu.library.ChartviewFileFields, rizu.library.ChartviewPlayStatFields, rizu.library.ChartviewMetaFields, rizu.library.ChartviewMetaUserDataFields, rizu.library.ChartviewDiffFields, rizu.library.ChartviewDiffPreviewFields, rizu.library.ChartviewRepoComputedFields

---@class rizu.library.LocatedChartview: rizu.library.Chartview
---@field location_prefix string
---@field location_dir string
---@field location_path string
---@field real_dir string
---@field real_path string

---@class rizu.library.ChartviewPlayFields
---@field nearest boolean
---@field tap_only boolean
---@field timings sea.Timings?
---@field subtimings sea.Subtimings?
---@field healths sea.Healths?
---@field columns_order integer[]?
---@field custom boolean
---@field const boolean
---@field rate_type sea.RateType

---@class rizu.library.Chartplayview: rizu.library.Chartview, rizu.library.ChartviewPlayFields

---@class rizu.library.ChartplayList: rizu.library.Chartview
---@field chartplay_id integer
---@field user_id integer
---@field compute_state integer
---@field computed_at integer
---@field submitted_at integer
---@field replay_hash string
---@field pause_count integer
---@field created_at integer
---@field judges integer[]
---@field max_combo integer
---@field not_perfect_count integer
---@field pass boolean
---@field rating number
---@field rating_pp number
---@field rating_msd number

---@class rizu.library.ChartplayComputable
---@field id integer
---@field user_id integer
---@field compute_state integer
---@field computed_at integer
---@field submitted_at integer
---@field replay_hash string
---@field pause_count integer
---@field created_at integer
---@field hash string
---@field index integer
---@field modifiers sea.Modifier[]
---@field rate number
---@field mode sea.Gamemode
---@field nearest boolean
---@field tap_only boolean
---@field timings sea.Timings?
---@field subtimings sea.Subtimings?
---@field healths sea.Healths?
---@field columns_order integer[]?
---@field custom boolean
---@field const boolean
---@field rate_type sea.RateType
---@field judges integer[]
---@field accuracy number
---@field max_combo integer
---@field miss_count integer
---@field not_perfect_count integer
---@field pass boolean
---@field rating number
---@field rating_pp number
---@field rating_msd number
