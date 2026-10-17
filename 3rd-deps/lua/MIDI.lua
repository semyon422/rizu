---@diagnostic disable: codestyle-check, no-unknown, assign-type-mismatch
-- #!/usr/bin/lua
--require 'DataDumper'   -- http://lua-users.org/wiki/DataDumper
local M = {} -- public interface
M.Version = 'VERSION'
M.VersionDate = 'DATESTAMP'
-- 20170917 6.8 fix 153: bad argument #1 to 'char' and round dtime
-- 20160702 6.7 to_millisecs() now handles set_tempo across multiple Tracks
-- 20150921 6.5 segment restores controllers as well as patch and tempo
-- 20150920 6.4 segment respects a set_tempo exactly on the start time
-- 20150628 6.3 absent any set_tempo, default is 120bpm (see MIDI filespec 1.1)
-- 20150422 6.2 works with lua5.3
-- 20140609 6.1 switch pod and doc over to using moonrocks 
-- 20140108 6.0 in lua5.2 require('posix') returns the posix table
-- 20120504 5.9 add the contents of mid_opus_tracks()
-- 20111129 5.7 _encode handles empty tracks; score2stats num_notes_by_channel
-- 20111111 5.6 fix patch 45 and 46 in Number2patch, should be Pizz and Harp
-- 20110115 5.5 add mix_opus_tracks()
-- 20110126 5.4 "previous message repeated N times" to save space on stderr
-- 20110126 5.3 robustness fix if one note_on and multiple note_offs
-- 20110125 5.2 opus2score terminates unended notes at the end of the track
-- 20110124 5.1 the warnings in midi2opus display track_num
-- 20110122 5.0 sysex2midimode.get pythonism eliminated
-- 20110119 4.9 copyright_text_event "time" item was missing
-- 20110110 4.8 note_on with velocity=0 treated as a note-off
-- 20110109 4.7 many global vars localised, passes lualint :-)
-- 20110108 4.6 duplicate int2sevenbits removed, passes lualint -r
-- 20110108 4.5 related end_track bugs fixed around line 516
-- 20110108 4.4 null text_event bug fixed
-- 20101026 4.3 segment() remembers all patch_changes, not just the list values
-- 20101010 4.2 play_score() uses posix.fork if available
-- 20101009 4.2 merge_scores() moves aside conflicting channels correctly
-- 20101006 4.1 concatenate_scores() deepcopys also its 1st score
-- 20101006 4.1 segment() uses start_time and end_time named arguments
-- 20101005 4.1 timeshift() must not pad the set_tempo command
-- 20101003 4.0 pitch2note_event must be chapitch2note_event
-- 20100918 3.9 set_sequence_number supported, FWIW
-- 20100918 3.8 timeshift and segment accept named args
-- 20100913 3.7 first released version

---------------------------- private -----------------------------
local sysex2midimode = {
	["\126\127\09\01\247"] = 1,
	["\126\127\09\02\247"] = 0,
	["\126\127\09\03\247"] = 2,
}

local previous_warning = '' -- 5.4
local previous_times = 0    -- 5.4
local function clean_up_warnings() -- 5.4
	-- Call this before returning from any publicly callable function
	-- whenever there's a possibility that a warning might have been printed
	-- by the function, or by any private functions it might have called.
	if previous_times > 1 then
		io.stderr:write('  previous message repeated '
		 ..previous_times..' times\n')
	elseif previous_times > 0 then
		io.stderr:write('  previous message repeated\n')
	end
	previous_times = 0
	previous_warning = ''
end
local function warn(str)
	if str == previous_warning then -- 5.4
		previous_times = previous_times + 1
	else
		clean_up_warnings()
		io.stderr:write(str,'\n')
		previous_warning = str
	end
end
local function die(str)
	clean_up_warnings()
	io.stderr:write(str,'\n')
	os.exit(1)
end
local function round(x) return math.floor(x+0.5) end

local function readOnly(t)  -- Programming in Lua, page 127
	local proxy = {}
	local mt = {
		__index = t,
		__newindex = function (t, k, v)
			die("attempt to update a read-only table")
		end
	}
	setmetatable(proxy, mt)
	return proxy
end

local function dict(a)
	local d = {}
	if a == nil then return d end
	for k,v in ipairs(a) do d[v] = true end
	return d
end

local function sorted_keys(t)
	local a = {}
	for k,v in pairs(t) do a[#a+1] = k end
	table.sort(a)
	return  a
end

local function int2byte(i)
	return string.char(math.floor((i+0.5) % 256))
end

local function int2sevenbits(i)
	return string.char(math.floor((i+0.5) % 128))
end

local function int2twobytes(i)
	local b1 = math.floor(i/256) % 256
	local b2 = i % 256
	return string.char(b1,b2)
end

local function twobytes2int(s)
	return 256*string.byte(string.sub(s,1)) + string.byte(string.sub(s,2))
end

local function int2fourbytes(i)
	local b1 = math.floor(i/16777216) % 256
	local b2 = math.floor(i/65536) % 256
	local b3 = math.floor(i/256) % 256
	local b4 = i % 256
	return string.char(b1,b2,b3,b4)
end

local function fourbytes2int(s)
	return 16777216*string.byte(string.sub(s,1)) +
	 65536 * string.byte(string.sub(s,2)) +
	 256*string.byte(string.sub(s,3)) + string.byte(string.sub(s,4))
end

local function read_14_bit(byte_a)
	-- decode a 14 bit quantity from two bytes,
	return string.byte(byte_a,1) + 128 * string.byte(byte_a,2)
end

local function write_14_bit(integer)
	-- encode a 14 bit quantity into two bytes,
	return string.char(integer % 128, math.floor(integer/128) % 128)
	-- return string.char((integer/128) % 128, integer % 128) 
end

local function ber_compressed_int(integer)
--[[BER compressed integer (not an ASN.1 BER, see perlpacktut for
details).  Its bytes represent an unsigned integer in base 128,
most significant digit first, with as few digits as possible.
Bit eight (the high bit) is set on each byte except the last.
]]
-- stderr.write('integer = ..',integer)
	-- warn('integer = '..tostring(integer)..' type '..type(integer))
	if integer == 0 then return '\000' end
	local ber = { string.char(integer % 128) }
	while integer > 127 do
		integer = math.floor(integer/128)
		local seven_bits = integer % 128
		table.insert(ber, 1, string.char(128+seven_bits))
	end
	return table.concat(ber)
end

local function str2ber_int(s, start)
--[[Given (a string, and a position within it), returns
(the ber_integer at that position, and the position after the ber_integer).
]]
	local i = start
	local integer = 0
	while true do
		local byte = string.byte(s, i)
		integer = integer + (byte%128)
		if byte < 127.5 then
			return integer, i+1
		end
		if i >= #s then
			warn('str2ber_int: no end-of-integer found')
			return 0, start
		end
		i = i + 1
		integer = integer * 128
	end
end

local function some_text_event(which_kind, text)
	if not which_kind then which_kind = 1 end
	if not text then text = 'some_text' end
	return '\255'..int2sevenbits(which_kind)..ber_compressed_int(text:len())..text
end

local function copy(t)
	local new_table = {}
	for k, v in pairs(t) do new_table[k] = v end
	return new_table
end

local function deepcopy(object)  -- http://lua-users.org/wiki/CopyTable
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end

local function _decode(trackdata, exclude, include, event_callback, exclusive_event_callback, no_eot_magic)
--[[Decodes MIDI track data into an opus-style list of events.
The options:
  'exclude' is a dictionary-table of event types which will be ignored
  'include' (and no exclude), makes exclude an array of all
      possible events, /minus/ what include specifies
  'event_callback' is a function
  'exclusive_event_callback' is a function
]]

	if not trackdata then trackdata= '' end
	if not exclude then exclude = {} end
	if not include then include = {} end
	if include and not exclude then exclude = M.All_events end  -- 4.6

	local event_code = -1 -- used for running status
	local event_count = 0
	local events = {}

	local i = 1     -- in Lua, i is the pointer to within the trackdata
	while i < #trackdata do   -- loop while there's anything to analyze
		local eot = false -- when True event registrar aborts this loop 4.6,4.7
   		event_count = event_count + 1

		local E = {} -- event; feed it to the event registrar at the end. 4.7

		-- Slice off the delta time code, and analyze it
		local time
		time, i = str2ber_int(trackdata, i)

		-- Now let's see what we can make of the command
		local first_byte = string.byte(trackdata,i); i = i+1

		if first_byte < 240 then  -- It's a MIDI event
			if first_byte % 256 > 127 then
				event_code = first_byte
			else
				-- It wants running status; use last event_code value
				i = i-1
				if event_code == -1 then
					warn("Running status not set; Aborting track.")
					return {}
				end
			end

			local command = math.floor(event_code / 16) * 16
			local channel = event_code % 16
			local parameter
			local param1
			local param2

			if command == 246 then  --  0-byte argument
				--pass
			elseif command == 192 or command == 208 then  --  1-byte arg
				parameter = string.byte(trackdata, i); i = i+1
			else -- 2-byte argument could be BB or 14-bit
				param1 = string.byte(trackdata, i); i = i+1
				param2 = string.byte(trackdata, i); i = i+1
			end

			----------------- MIDI events -----------------------

			local continue = false
			if command      == 128 then
				if exclude['note_off'] then
					continue = true
				else
					E = {'note_off', time, channel, param1, param2}
				end
			elseif command == 144 then
				if exclude['note_on'] then
					continue = true
				else
					E = {'note_on', time, channel, param1, param2}
				end
			elseif command == 160 then
				if exclude['key_after_touch'] then
					continue = true
				else
					E = {'key_after_touch',time,channel,param1,param2}
				end
			elseif command == 176 then
				if exclude['control_change'] then
					continue = true
				else
					E = {'control_change',time,channel,param1,param2}
				end
			elseif command == 192 then
				if exclude['patch_change'] then
					continue = true
				else
					E = {'patch_change', time, channel, parameter}
				end
			elseif command == 208 then
				if exclude['channel_after_touch'] then
					continue = true
				else
					E = {'channel_after_touch', time, channel, parameter}
				end
			elseif command == 224 then
				if exclude['pitch_wheel_change'] then
					continue = true
				else -- the 2 param bytes are a 14-bit int
					E = {'pitch_wheel_change', time, channel,
					 128*param2+param1-8192}
				end
			else
				warn("Shouldn't get here; command="..tostring(command))
			end

		elseif first_byte == 255 then  -- It's a Meta-Event!
			local command = string.byte(trackdata, i); i = i+1
			local length
			length, i = str2ber_int(trackdata, i)
			if (command      == 0) then
				if length == 2 then  -- 3.9
					E = {'set_sequence_number', time,
					 twobytes2int(string.sub(trackdata,i,i+1)) }
				else
					warn('set_sequence_number: length must be 2, not '
					 .. tostring(length))
					E = {'set_sequence_number', time, 0}
				end

			-- Defined text events ------
			elseif command == 1 then
				E = {'text_event', time, string.sub(trackdata,i,i+length-1)}
			elseif command == 2 then  -- 4.9
				E = {'copyright_text_event', time, string.sub(trackdata,i,i+length-1)}
			elseif command == 3 then
				E = {'track_name',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 4 then
				E = {'instrument_name',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 5 then
				E = {'lyric',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 6 then
				E = {'marker',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 7 then
				E = {'cue_point',time, string.sub(trackdata,i,i+length-1)}

			-- Reserved but apparently unassigned text events -------------
			elseif command == 8 then
				E = {'text_event_08',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 9 then
				E = {'text_event_09',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 10 then
				E = {'text_event_0a',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 11 then
				E = {'text_event_0b',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 12 then
				E = {'text_event_0c',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 13 then
				E = {'text_event_0d',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 14 then
				E = {'text_event_0e',time, string.sub(trackdata,i,i+length-1)}
			elseif command == 15 then
				E = {'text_event_0f',time, string.sub(trackdata,i,i+length-1)}
			
			-- Now the sticky events -------------------------------------
			elseif command == 47 then
				E = {'end_track', time}
				-- The code for handling this, oddly, comes LATER,
				-- in the event registrar.
			elseif command == 81 then -- DTime, Microseconds/Crochet
				if length ~= 3 then
					warn('set_tempo event, but length='..length)
				end
				E = {'set_tempo', time,
					string.byte(trackdata,i) * 65536
					+ string.byte(trackdata,i+1) * 256
					+ string.byte(trackdata,i+2)
				}
			elseif command == 84 then
				if length ~= 5 then   -- DTime, HR, MN, SE, FR, FF
					warn('smpte_offset event, but length='..length)
				end
				E = {'smpte_offset', time,
					string.byte(trackdata,i),
					string.byte(trackdata,i+1),
					string.byte(trackdata,i+2),
					string.byte(trackdata,i+3),
					string.byte(trackdata,i+4)
				}
			elseif command == 88 then
				if length ~= 4 then   -- DTime, NN, DD, CC, BB
					warn('time_signature event, but length='..length)
				end
				E = {'time_signature', time,
					string.byte(trackdata,i),
					string.byte(trackdata,i+1),
					string.byte(trackdata,i+2),
					string.byte(trackdata,i+3)
				}
			elseif command == 89 then
				if length ~= 2 then   -- DTime, SF(signed), MI
					warn('key_signature event, but length='..length)
				end
				local b1 = string.byte(trackdata,i)
				if b1 > 127 then b1 = b1 - 256 end   -- signed byte :-(
				local b2 = string.byte(trackdata,i+1)
				-- list(struct.unpack(">bB",trackdata[0:2]))}
				E = {'key_signature', time, b1, b2 }
			elseif (command == 127) then
				E = {'sequencer_specific',time,
					string.sub(trackdata,i,i+length-1)}
			else
				E = {'raw_meta_event', time, command,
					string.sub(trackdata,i,i+length-1)}
				--"[uninterpretable meta-event command of length length]"
				-- DTime, Command, Binary Data
				-- It's uninterpretable; record it as raw_data.
			end

			-- Pointer += length; --  Now move Pointer
			i = i + length
			-- Hmm... in lua, we should be using Pointer again....
			-- trackdata =  string.sub(trackdata, length+1)

		--#####################################################################
		elseif first_byte == 240 or first_byte == 247 then
			-- Note that sysexes in MIDI /files/ are different than sysexes
			-- in MIDI transmissions!! The vast majority of system exclusive
			-- messages will just use the F0 format. For instance, the
			-- transmitted message F0 43 12 00 07 F7 would be stored in a
			-- MIDI file as F0 05 43 12 00 07 F7. As mentioned above, it is
			-- required to include the F7 at the end so that the reader of the
			-- MIDI file knows that it has read the entire message. (But the F7
			-- is omitted if this is a non-final block in a multiblock sysex;
			-- but the F7 (if there) is counted in the message's declared
			-- length, so we don't have to think about it anyway.)
			--command = trackdata.pop(0)
			local length
			length, i = str2ber_int(trackdata, i)
			if first_byte == 240 then
				-- 20091008 added ISO-8859-1 to get an 8-bit str
				E = {'sysex_f0', time, string.sub(trackdata,i,i+length-1)}
			else
				E = {'sysex_f7', time, string.sub(trackdata,i,i+length-1)}
			end
			i = i + length
			-- trackdata =  string.sub(trackdata, length+1)

		--#####################################################################
		-- Now, the MIDI file spec says:
		--  <track data> = <MTrk event>+
		--  <MTrk event> = <delta-time> <event>
		--  <event> = <MIDI event> | <sysex event> | <meta-event>
		-- I know that, on the wire, <MIDI event> can include note_on,
		-- note_off, and all the other 8x to Ex events, AND Fx events
		-- other than F0, F7, and FF -- namely, <song position msg>,
		-- <song select msg>, and <tune request>.
		--
		-- Whether these can occur in MIDI files is not clear specified
		-- from the MIDI file spec.  So, I'm going to assume that
		-- they CAN, in practice, occur.  I don't know whether it's
		-- proper for you to actually emit these into a MIDI file.
		
		elseif first_byte == 242 then   -- DTime, Beats
			--  <song position msg> ::=     F2 <data pair>
			E = {'song_position', time, read_14_bit(string.sub(trackdata,i))}
			trackdata = string.sub(trackdata,3)

		elseif first_byte == 243 then -- <song select> ::= F3 <data singlet>
			-- E=['song_select', time, struct.unpack('>B',trackdata.pop(0))[0]]
			E = {'song_select', time, string.byte(trackdata,i)}
			-- trackdata = trackdata[1:]
			trackdata = string.sub(trackdata,2)
			-- DTime, Thing (what?! song number?  whatever ...)

		elseif first_byte == 246 then   -- DTime
			E = {'tune_request', time}
			-- What would a tune request be doing in a MIDI /file/?

		--########################################################
		-- ADD MORE META-EVENTS HERE.  TODO:
		-- f1 -- MTC Quarter Frame Message. One data byte follows
		--     the Status; it's the time code value, from 0 to 127.
		-- f8 -- MIDI clock.    no data.
		-- fa -- MIDI start.    no data.
		-- fb -- MIDI continue. no data.
		-- fc -- MIDI stop.     no data.
		-- fe -- Active sense.  no data.
		-- f4 f5 f9 fd -- unallocated

--[[
		elseif (first_byte > 240) { -- Some unknown kinda F-series event ####
			-- Here we only produce a one-byte piece of raw data.
			-- But the encoder for 'raw_data' accepts any length of it.
			E = [ 'raw_data', time, substr(trackdata,Pointer,1) ]
			-- DTime and the Data (in this case, the one Event-byte)
			++Pointer;  -- itself

]]
		elseif first_byte > 240 then  -- Some unknown F-series event
			-- Here we only produce a one-byte piece of raw data.
			E = {'raw_data', time, string.byte(trackdata,i)}  -- 4.6
			trackdata = string.sub(trackdata,2)  -- 4.6
		else  -- Fallthru.
			warn(string.format("Aborting track.  Command-byte first_byte=0x%x",first_byte)) --4.6
			break
		end
		-- End of the big if-group


		--#####################################################################
		--  THE EVENT REGISTRAR...
		-- warn('3: E='+str(E))
		if E and  E[1] == 'end_track' then
			-- This is the code for exceptional handling of the EOT event.
			eot = true
			if not no_eot_magic then
				if E[2] > 0 then  -- a null text-event to carry the delta-time
					E = {'text_event', E[2], ''}  -- 4.4
				else
					E = nil   -- EOT with a delta-time of 0; ignore it.
				end
			end
		end

		if E and not exclude[E[1]] then
			--if ( $exclusive_event_callback ):
			--    &{ $exclusive_event_callback }( @E );
			--else
			--    &{ $event_callback }( @E ) if $event_callback;
			events[#events+1] = E
		end
		if eot then break end
	end
	-- End of the big "Event" while-block

	return events
end

local function _encode(events_lol)
	local no_running_status = false
	local no_eot_magic      = false   -- 4.6
	local never_add_eot     = false   -- 4.6
	local unknown_callback  = false   -- 4.6
	local data = {} -- what I'll store the chunks of byte-data in

	-- This is so my end_track magic won't corrupt the original
	local events = deepcopy(events_lol)

	if not never_add_eot then -- One way or another, tack on an 'end_track'
		if #events > 0 then   -- 5.7
			local last = events[#events] -- 4.5, 4.7
			if not (last[1] == 'end_track') then  -- no end_track already
				if (last[1] == 'text_event' and last[3] == '') then -- 4.5,4.6
					-- 0-length text event at track-end. 
					if no_eot_magic then
						-- Exceptional case: don't mess with track-final
						-- 0-length text_events; just peg on an end_track
						events.append({'end_track', 0})
					else
						-- NORMAL CASE: replace with an end_track, leaving DTime
						last[1] = 'end_track'
					end
				else
					-- last event was neither 0-length text_event nor end_track
					events[#events+1] = {'end_track', 0}
				end
			end
		else  -- an eventless track!
			events = { {'end_track', 0},}
		end
	end

	-- maybe_running_status = not no_running_status  -- unused? 4.7
	local last_status = -1 -- 4.7

	for k,E in ipairs(events) do
		-- get rid of the two pop's and increase the other E[] indices by two
		if not E then break end

		local event = E[1] -- 4.7
		if #event < 1 then break end

		local dtime = round(E[2]) -- 4.7 6.8
		-- print('event='..event..' dtime='..dtime)

		local event_data = '' -- 4.7

		if    -- MIDI events -- eligible for running status
			 event	== 'note_on'
			 or event == 'note_off'
			 or event == 'control_change'
			 or event == 'key_after_touch'
			 or event == 'patch_change'
			 or event == 'channel_after_touch'
			 or event == 'pitch_wheel_change'   then

			-- This block is where we spend most of the time.  Gotta be tight.
			local status = nil     -- 4.7
			local parameters = nil -- 4.7
			if (event == 'note_off') then
				status = 128 + (E[3] % 16)
				parameters = int2sevenbits(E[4]%128)..int2sevenbits(E[5]%128)
			elseif event == 'note_on' then
				status = 144 + (E[3] % 16)
				parameters = int2sevenbits(E[4]) .. int2sevenbits(E[5])
			elseif event == 'key_after_touch' then
				status = 160 + (E[3] % 16)
				parameters = int2sevenbits(E[4]) .. int2sevenbits(E[5])
			elseif event == 'control_change' then
				status = 176 + (E[3] % 16)
				parameters = int2sevenbits(E[4]) .. int2sevenbits(E[5])
			elseif event == 'patch_change' then
				status = 192 + (E[3] % 16)
				parameters = int2sevenbits(E[4])
			elseif event == 'channel_after_touch' then
				status = 208 + (E[3] % 16)
				parameters = int2sevenbits(E[4])
			elseif event == 'pitch_wheel_change' then
				status = 224 + (E[3] % 16)
				parameters =  write_14_bit(E[4] + 8192)
			else
				warn("BADASS FREAKOUT ERROR 31415!")
			end

			-- And now the encoding

			data[#data+1] = ber_compressed_int(dtime)
			if (status ~= last_status) or no_running_status then
				data[#data+1] = int2byte(status)
			end
			data[#data+1] = parameters
			last_status = status
			-- break
		else
			-- Not a MIDI event.
			last_status = -1

			if event == 'raw_meta_event' then
				event_data = some_text_event(E[3], E[4])
			elseif (event == 'set_sequence_number') then  -- 3.9
				event_data = some_text_event(0, int2twobytes(E[3]))

			-- Text Meta-events...
			-- a case for a dict, I think (pjb) ...
			elseif (event == 'text_event') then
				event_data = some_text_event(1, E[3])
			elseif (event == 'copyright_text_event') then
				event_data = some_text_event(2, E[3])
			elseif (event == 'track_name') then
				event_data = some_text_event(3, E[3])
			elseif (event == 'instrument_name') then
				event_data = some_text_event(4, E[3])
			elseif (event == 'lyric') then
				event_data = some_text_event(5, E[3])
			elseif (event == 'marker') then
				event_data = some_text_event(6, E[3])
			elseif (event == 'cue_point') then
				event_data = some_text_event(7, E[3])
			elseif (event == 'text_event_08') then
				event_data = some_text_event(8, E[3])
			elseif (event == 'text_event_09') then
				event_data = some_text_event(9, E[3])
			elseif (event == 'text_event_0a') then
				event_data = some_text_event(10, E[3])
			elseif (event == 'text_event_0b') then
				event_data = some_text_event(11, E[3])
			elseif (event == 'text_event_0c') then
				event_data = some_text_event(12, E[3])
			elseif (event == 'text_event_0d') then
				event_data = some_text_event(13, E[3])
			elseif (event == 'text_event_0e') then
				event_data = some_text_event(14, E[3])
			elseif (event == 'text_event_0f') then
				event_data = some_text_event(15, E[3])
			-- End of text meta-events

			elseif (event == 'end_track') then
				event_data = '\255\47\0'
			elseif (event == 'set_tempo') then
				--event_data = struct.pack(">BBwa*", 0xFF, 0x51, 3,
				--			  substr( struct.pack('>I', E[0]), 1, 3))
				event_data = '\255\81\03' .. string.sub(int2fourbytes(E[3]),2)
				-- XXX don't understand that ?!
			elseif (event == 'smpte_offset') then
				event_data = '\255\84\05' ..
					string.char(E[3],E[4],E[5],E[6],E[7])
			elseif (event == 'time_signature') then
				event_data = '\255\88\04' .. string.char(E[3],E[4],E[5],E[6])
			elseif (event == 'key_signature') then
				local e3 = E[3]; if e3<0 then e3 = 256+e3 end  -- signed byte
				event_data = '\255\89\02' .. string.char(e3,E[4])
			elseif (event == 'sequencer_specific') then
				event_data = some_text_event(127, E[3])
			-- End of Meta-events

			-- Other Things...
			elseif (event == 'sysex_f0') then
				event_data =
				 "\240"..ber_compressed_int(string.len(E[3]))..E[3]
			elseif (event == 'sysex_f7') then
				event_data =
				 "\247"..ber_compressed_int(string.len(E[3]))..E[3]
			elseif (event == 'song_position') then
				 event_data = "\242"..write_14_bit( E[3] )
			elseif (event == 'song_select') then
				 event_data = "\243"..string.char(E[3])
			elseif (event == 'tune_request') then
				 event_data = "\246"
			elseif (event == 'raw_data') then
				warn("_encode: raw_data event not supported")
				break
			-- End of Other Stuff

			-- The Big Fallthru
			else
				if not unknown_callback then
					warn("Unknown event: "..tostring(event))
				end
				break
			end

			--print "Event $event encoded part 2\n"
			--if str(type(event_data)).find('str') >= 0 then
			--	event_data = bytearray(event_data.encode('Latin1', 'ignore'))
			--end
			if event_data and (#event_data > 0) then -- how could it be empty?
				-- data.append(struct.pack('>wa*', dtime, event_data))
				-- print(' event_data='+str(event_data))
				data[#data+1] = ber_compressed_int(dtime)
				data[#data+1] = event_data
			end
		end
	end
	return table.concat(data)
end

local function consistentise_ticks(scores) -- 3.6
	-- used by mix_scores, merge_scores, concatenate_scores
	if #scores == 1 then return deepcopy(scores) end
	local are_consistent = true
	local ticks = scores[1][1]
	for iscore = 2,#scores do
		if scores[iscore][1] ~= ticks then
			are_consistent = false
			break
		end
	end
	if are_consistent then return deepcopy(scores) end
	local new_scores = {}
	for ks,score in ipairs(scores) do
		new_scores[ks] = M.opus2score(M.to_millisecs(M.score2opus(score)))
	end
	return new_scores
end

-------------------------- public ------------------------------
M.All_events = readOnly{
	note_off=true, note_on=true, key_after_touch=true, control_change=true,
	patch_change=true, channel_after_touch=true, pitch_wheel_change=true,
	text_event=true, copyright_text_event=true, track_name=true,
	instrument_name=true, lyric=true, marker=true, cue_point=true,
	text_event_08=true, text_event_09=true, text_event_0a=true,
	text_event_0b=true, text_event_0c=true, text_event_0d=true,
	text_event_0e=true, text_event_0f=true,
	end_track=true, set_tempo=true, smpte_offset=true,
	time_signature=true, key_signature=true,
	sequencer_specific=true, raw_meta_event=true,
	sysex_f0=true, sysex_f7=true,
	song_position=true, song_select=true, tune_request=true,
}
-- And three dictionaries:
M.Number2patch = readOnly{   -- General MIDI patch numbers:
[0]='Acoustic Grand',
[1]='Bright Acoustic',
[2]='Electric Grand',
[3]='Honky-Tonk',
[4]='Electric Piano 1',
[5]='Electric Piano 2',
[6]='Harpsichord',
[7]='Clav',
[8]='Celesta',
[9]='Glockenspiel',
[10]='Music Box',
[11]='Vibraphone',
[12]='Marimba',
[13]='Xylophone',
[14]='Tubular Bells',
[15]='Dulcimer',
[16]='Drawbar Organ',
[17]='Percussive Organ',
[18]='Rock Organ',
[19]='Church Organ',
[20]='Reed Organ',
[21]='Accordion',
[22]='Harmonica',
[23]='Tango Accordion',
[24]='Acoustic Guitar(nylon)',
[25]='Acoustic Guitar(steel)',
[26]='Electric Guitar(jazz)',
[27]='Electric Guitar(clean)',
[28]='Electric Guitar(muted)',
[29]='Overdriven Guitar',
[30]='Distortion Guitar',
[31]='Guitar Harmonics',
[32]='Acoustic Bass',
[33]='Electric Bass(finger)',
[34]='Electric Bass(pick)',
[35]='Fretless Bass',
[36]='Slap Bass 1',
[37]='Slap Bass 2',
[38]='Synth Bass 1',
[39]='Synth Bass 2',
[40]='Violin',
[41]='Viola',
[42]='Cello',
[43]='Contrabass',
[44]='Tremolo Strings',
[45]='Pizzicato Strings',
[46]='Orchestral Harp',
[47]='Timpani',
[48]='String Ensemble 1',
[49]='String Ensemble 2',
[50]='SynthStrings 1',
[51]='SynthStrings 2',
[52]='Choir Aahs',
[53]='Voice Oohs',
[54]='Synth Voice',
[55]='Orchestra Hit',
[56]='Trumpet',
[57]='Trombone',
[58]='Tuba',
[59]='Muted Trumpet',
[60]='French Horn',
[61]='Brass Section',
[62]='SynthBrass 1',
[63]='SynthBrass 2',
[64]='Soprano Sax',
[65]='Alto Sax',
[66]='Tenor Sax',
[67]='Baritone Sax',
[68]='Oboe',
[69]='English Horn',
[70]='Bassoon',
[71]='Clarinet',
[72]='Piccolo',
[73]='Flute',
[74]='Recorder',
[75]='Pan Flute',
[76]='Blown Bottle',
[77]='Skakuhachi',
[78]='Whistle',
[79]='Ocarina',
[80]='Lead 1 (square)',
[81]='Lead 2 (sawtooth)',
[82]='Lead 3 (calliope)',
[83]='Lead 4 (chiff)',
[84]='Lead 5 (charang)',
[85]='Lead 6 (voice)',
[86]='Lead 7 (fifths)',
[87]='Lead 8 (bass+lead)',
[88]='Pad 1 (new age)',
[89]='Pad 2 (warm)',
[90]='Pad 3 (polysynth)',
[91]='Pad 4 (choir)',
[92]='Pad 5 (bowed)',
[93]='Pad 6 (metallic)',
[94]='Pad 7 (halo)',
[95]='Pad 8 (sweep)',
[96]='FX 1 (rain)',
[97]='FX 2 (soundtrack)',
[98]='FX 3 (crystal)',
[99]='FX 4 (atmosphere)',
[100]='FX 5 (brightness)',
[101]='FX 6 (goblins)',
[102]='FX 7 (echoes)',
[103]='FX 8 (sci-fi)',
[104]='Sitar',
[105]='Banjo',
[106]='Shamisen',
[107]='Koto',
[108]='Kalimba',
[109]='Bagpipe',
[110]='Fiddle',
[111]='Shanai',
[112]='Tinkle Bell',
[113]='Agogo',
[114]='Steel Drums',
[115]='Woodblock',
[116]='Taiko Drum',
[117]='Melodic Tom',
[118]='Synth Drum',
[119]='Reverse Cymbal',
[120]='Guitar Fret Noise',
[121]='Breath Noise',
[122]='Seashore',
[123]='Bird Tweet',
[124]='Telephone Ring',
[125]='Helicopter',
[126]='Applause',
[127]='Gunshot',
}

M.Notenum2percussion = readOnly{   -- General MIDI Percussion (on Channel 9):
[33]='Metronome Click',
[34]='Metronome Bell',
[35]='Acoustic Bass Drum',
[36]='Bass Drum 1',
[37]='Side Stick',
[38]='Acoustic Snare',
[39]='Hand Clap',
[40]='Electric Snare',
[41]='Low Floor Tom',
[42]='Closed Hi-Hat',
[43]='High Floor Tom',
[44]='Pedal Hi-Hat',
[45]='Low Tom',
[46]='Open Hi-Hat',
[47]='Low-Mid Tom',
[48]='Hi-Mid Tom',
[49]='Crash Cymbal 1',
[50]='High Tom',
[51]='Ride Cymbal 1',
[52]='Chinese Cymbal',
[53]='Ride Bell',
[54]='Tambourine',
[55]='Splash Cymbal',
[56]='Cowbell',
[57]='Crash Cymbal 2',
[58]='Vibraslap',
[59]='Ride Cymbal 2',
[60]='Hi Bongo',
[61]='Low Bongo',
[62]='Mute Hi Conga',
[63]='Open Hi Conga',
[64]='Low Conga',
[65]='High Timbale',
[66]='Low Timbale',
[67]='High Agogo',
[68]='Low Agogo',
[69]='Cabasa',
[70]='Maracas',
[71]='Short Whistle',
[72]='Long Whistle',
[73]='Short Guiro',
[74]='Long Guiro',
[75]='Claves',
[76]='Hi Wood Block',
[77]='Low Wood Block',
[78]='Mute Cuica',
[79]='Open Cuica',
[80]='Mute Triangle',
[81]='Open Triangle',
}

M.Event2channelindex = readOnly{ ['note']=4, ['note_off']=3, ['note_on']=3,
 ['key_after_touch']=3, ['control_change']=3, ['patch_change']=3,
 ['channel_after_touch']=3, ['pitch_wheel_change']=3,
}

function M.concatenate_scores(scores)
	-- the deepcopys are needed if input_scores are refs to the same table
	-- e.g. if invoked by midisox's repeat()
	local input_scores = consistentise_ticks(scores) -- 3.6
	local output_score = deepcopy(input_scores[1])   -- 4.2
	for i = 2,#input_scores do
		local input_score = input_scores[i]
		local output_stats = M.score2stats(output_score)
		local delta_ticks = output_stats['nticks']
		for itrack = 2,#input_score do
			if itrack > #output_score then -- new output track if doesn't exist
				output_score[#output_score+1] = {}
			end
			for k,event in ipairs(input_score[itrack]) do
				local new_event = copy(event)
				new_event[2] = new_event[2] + delta_ticks
				table.insert(output_score[itrack], new_event)
				-- output_score[itrack][-1][1] += delta_ticks  -- hmm...
			end
		end
	end
	return output_score
end

function M.grep(score, t)
	if score == nil then return {1000,{},} end
	local ticks = score[1]
	local new_score = {ticks,{},}
	if not t or type(t) ~= 'table' then return new_score end
	local channels = dict(t)
	local itrack = 2 while itrack <= #score do
		new_score[itrack] = {}
		for k,event in ipairs(score[itrack]) do
			local channel_index = M.Event2channelindex[event[1]]
			if channel_index then
				if channels[event[channel_index]] then
					table.insert(new_score[itrack], event)
				end
			else
				table.insert(new_score[itrack], event)
			end
		end
		itrack = itrack + 1
	end
	return new_score
end

function M.merge_scores(scores)
	local output_score = {1000,}
	local channels_so_far = {}
	local all_channels = dict{0,1,2,3,4,5,6,7,8,10,11,12,13,14,15}
	for ks,input_score in ipairs(consistentise_ticks(scores)) do -- 3.6
		local new_stats = M.score2stats(input_score)
		local new_channels = dict(new_stats['channels_total']) -- 4.2 dict
		new_channels[9] = nil  -- 2.8 cha9 must remain cha9 (in GM)
		for j,channel in ipairs(sorted_keys(new_channels)) do  -- 4.2 to catch 0
			if channels_so_far[channel] then
				local free_channels = copy(all_channels)
				for k,v in pairs(channels_so_far) do
					if v then free_channels[k] = nil end
				end
				for k,v in pairs(new_channels) do
					if v then free_channels[k] = nil end
				end
				-- consistently choose lowest avaiable, to ease testing
				local free_channel = nil
                local fcs = sorted_keys(free_channels)
				if #fcs > 0 then
                    free_channel = fcs[1]
				else
					break
				end
				for itrack = 2,#input_score do
					for k3,input_event in ipairs(input_score[itrack]) do
						local ci = M.Event2channelindex[input_event[1]]
						if ci and input_event[ci]==channel then
							input_event[ci] = free_channel
						end
					end
				end
				channels_so_far[free_channel] = true
			end
			channels_so_far[channel] = true
		end
	   	for itrack = 2,#input_score do
			output_score[#output_score+1] = input_score[itrack]
		end
	end
	return output_score
end

function M.mix_opus_tracks(input_tracks) -- 5.5
	-- must convert each track to absolute times !
	local output_score = {1000, {}}
	for ks,input_track in ipairs(input_tracks) do -- 5.8
		local input_score = M.opus2score({1000, input_track})
		for k,event in ipairs(input_score[2]) do
			table.insert(output_score[2], event)
		end
	end
	table.sort(output_score[2], function (e1,e2) return e1[2]<e2[2] end) 
	local output_opus = M.score2opus(output_score)
	return output_opus[2]
end

function M.mix_scores(input_scores)
	local output_score = {1000, {}}
	for ks,input_score in ipairs(consistentise_ticks(input_scores)) do -- 3.6
	   	for itrack = 2,#input_score do
			for k,event in ipairs(input_score[itrack]) do
				table.insert(output_score[2], event)
			end
		end
	end
	return output_score
end

function M.midi2ms_score(midi)
	return M.opus2score(M.to_millisecs(M.midi2opus(midi)))
end

function M.midi2opus(s)
	if not s then s = '' end
	--my_midi=bytearray(midi)
	if #s < 4 then return {1000,{},} end
	local i = 1
	local id = string.sub(s, i, i+3); i = i+4
	if id ~= 'MThd' then
		warn("midi2opus: midi starts with "..id.." instead of 'MThd'")
		clean_up_warnings()
		return {1000,{},}
	end
	-- h:short; H:unsigned short; i:int; I:unsigned int;
	-- l:long; L:unsigned long; f:float; d:double.
	-- [length, format, tracks_expected, ticks] = struct.unpack(
	--  '>IHHH', bytes(my_midi[4:14]))  is this 10 bytes or 14 ?
	-- NOT 2+4+4+4 grrr...   'MHhd'+4+2+2+2 !
	local length          = fourbytes2int(string.sub(s,i,i+3)); i = i+4
	local format          = twobytes2int(string.sub(s,i,i+1)); i = i+2
	local tracks_expected = twobytes2int(string.sub(s,i,i+1)); i = i+2
	local ticks           = twobytes2int(string.sub(s,i,i+1)); i = i+2
	if length ~= 6 then
		warn("midi2opus: midi header length was "..tostring(length).." instead of 6")
		clean_up_warnings()
		return {1000,{},}
	end
	local my_opus = {ticks,}
	local track_num = 1   -- 5.1
	while i < #s-8 do
		local track_type   = string.sub(s, i, i+3); i = i+4
		if track_type ~= 'MTrk' then
			warn('midi2opus: Warning: track #'..track_num..' type is '..track_type.." instead of 'MTrk'")
		end
		local track_length = fourbytes2int(string.sub(s,i,i+3)); i = i+4
		if track_length > #s then
			warn('midi2opus: track #'..track_num..' length '..track_length..' is too large')
			clean_up_warnings()
			return my_opus  -- 4.9
		end
		local my_midi_track = string.sub(s, i, i+track_length-1) -- 4.7
		i = i+track_length
		local my_track = _decode(my_midi_track) -- 4.7
		my_opus[#my_opus+1] = my_track
		track_num = track_num + 1   -- 5.1
	end
	clean_up_warnings()
	return my_opus
end

function M.midi2score(midi)
	return M.opus2score(M.midi2opus(midi))
end

function M.play_score(score)
	if not score then return end
	local midi
	if M.score_type(score) == 'opus' then
		midi = M.opus2midi(score)
	else
		midi = M.score2midi(score)
	end
	local posix  -- 6.0 in lua5.2 require posix returns the posix table
	pcall(function() posix = require 'posix' end)
	if posix and posix.fork then   -- 4.2
		local pid = posix.fork()
        if pid == 0 then
			local p = assert(io.popen("aplaymidi -", 'w'))  -- background
            p:write(midi) ; p:close() ; os.exit(0)
        end
	else
		local fn = os.tmpname()
		local fh = assert(io.open(fn, 'w'));  fh:write(midi);  fh:close()
		os.execute("aplaymidi "..fn..' ; rm '..fn..' &')
	end
end

function M.opus2midi(opus)
	if #opus < 2 then opus = {1000, {},} end
	-- tracks = copy.deepcopy(opus)
	local ntracks = #opus - 1
	local ticks = opus[1]
	local format
	if ntracks == 1 then format = 0 else format = 1 end
	local my_midi = "MThd\00\00\00\06" ..
	 int2twobytes(format) .. int2twobytes(ntracks) .. int2twobytes(ticks)
	-- struct.pack('>HHH',format,ntracks,ticks)
	--for track in tracks:
	for i = 2, #opus do
		local events = _encode(opus[i])
		-- should really do an array and then concat...
		my_midi = my_midi .. 'MTrk' .. int2fourbytes(#events) .. events
	end
	clean_up_warnings()
	return my_midi
end

function M.opus2score(opus)
	if opus == nil or #opus < 2 then return {1000,{},} end
	local ticks = opus[1]
	local score = {ticks,}
	local itrack = 2; while itrack <= #opus do
		local opus_track = opus[itrack]
		local ticks_so_far = 0
		local score_track = {}
		local chapitch2note_on_events = {}   -- 4.0
		local k; for k,opus_event in ipairs(opus_track) do
			ticks_so_far = ticks_so_far + opus_event[2]
			if opus_event[1] == 'note_off' or
			 (opus_event[1] == 'note_on' and opus_event[5] == 0) then -- 4.8
				local cha = opus_event[3]  -- 4.0
				local pitch = opus_event[4]
				local key = cha*128 + pitch  -- 4.0
				local pending_notes = chapitch2note_on_events[key] -- 5.3
				if pending_notes and #pending_notes > 0 then
					local new_e = table.remove(pending_notes, 1)
					new_e[3] = ticks_so_far - new_e[2]
					score_track[#score_track+1] = new_e
				elseif pitch > 127 then
					warn('opus2score: note_off with no note_on, bad pitch='
					 ..tostring(pitch))
				else
					warn('opus2score: note_off with no note_on cha='
					 ..tostring(cha)..' pitch='..tostring(pitch))
				end
			elseif opus_event[1] == 'note_on' then
				local cha = opus_event[3]  -- 4.0
				local pitch = opus_event[4]
				local new_e = {'note',ticks_so_far,0,cha,pitch,opus_event[5]}
				local key = cha*128 + pitch  -- 4.0
				if chapitch2note_on_events[key] then
					table.insert(chapitch2note_on_events[key], new_e)
				else
					chapitch2note_on_events[key] = {new_e,}
				end
			else
				local new_e = copy(opus_event)
				new_e[2] = ticks_so_far
				score_track[#score_track+1] = new_e
			end
		end
		-- check for unterminated notes (Oisín) -- 5.2
		for chapitch,note_on_events in pairs(chapitch2note_on_events) do
			for k,new_e in ipairs(note_on_events) do
				new_e[3] = ticks_so_far - new_e[2]
				score_track[#score_track+1] = new_e
				--warn("adding unterminated note: {'"..new_e[1].."', "..new_e[2]
				-- ..', '..new_e[3]..', '..new_e[4]..', '..new_e[5]..'}')
				warn("opus2score: note_on with no note_off cha="..new_e[4]
				 ..' pitch='..new_e[5]..'; adding note_off at end')
			end
		end
		score[#score+1] = score_track
		itrack = itrack + 1
	end
	clean_up_warnings()
	return score
end

function M.score2opus(score)
	if score == nil or #score < 2 then return {1000,{},} end
	local ticks = score[1]
	local opus = {ticks,}
	local itrack = 2; while itrack <= #score do
		local score_track = score[itrack]
		local time2events = {}
		local k,scoreevent; for k,scoreevent in ipairs(score_track) do
			local continue = false
			if scoreevent[1] == 'note' then
				local note_on_event = {'note_on',scoreevent[2],
				 scoreevent[4],scoreevent[5],scoreevent[6]}
				local note_off_event = {'note_off',scoreevent[2]+scoreevent[3],
				 scoreevent[4],scoreevent[5],scoreevent[6]}
				if time2events[note_on_event[2]] then
				   table.insert(time2events[note_on_event[2]], note_on_event)
				else
				   time2events[note_on_event[2]] = {note_on_event,}
				end
				if time2events[note_off_event[2]] then
				   table.insert(time2events[note_off_event[2]], note_off_event)
				else
				   time2events[note_off_event[2]] = {note_off_event,}
				end
				continue = true
			end
			if not continue then
				if time2events[scoreevent[2]] then
					table.insert(time2events[scoreevent[2]], scoreevent)
				else
					time2events[scoreevent[2]] = {scoreevent, }
				end
			end
		end
		local sorted_times = {}  -- list of keys
		for k,v in pairs(time2events) do
			sorted_times[#sorted_times+1] = k
		end
		table.sort(sorted_times)
		local sorted_events = {} -- once-flattened list of values sorted by key
		for k,time in ipairs(sorted_times) do
			for k2,v in ipairs(time2events[time]) do
				--sorted_events[#sorted_events+1] = v NOPE, must copy!
				sorted_events[#sorted_events+1] = {}
				for k3,v3 in ipairs(v) do
					table.insert(sorted_events[#sorted_events],v3)
				end
			end
		end
		local abs_time = 0
		for k,event in ipairs(sorted_events) do  -- abs times => delta times
			local delta_time = event[2] - abs_time
			abs_time = event[2]
			event[2] = delta_time
		end
		opus[#opus+1] = sorted_events
		itrack = itrack + 1
	end
	clean_up_warnings()
	return opus
end

function M.score_type(t)
	if t == nil or type(t) ~= 'table' or #t < 2 then return '' end
	local i = 2   -- ignore first element  -- 4.7
	while i <= #t do
		local k,event; for k,event in ipairs(t[i]) do
			if event[1] == 'note' then
				return 'score'
			elseif event[1] == 'note_on' then
				return 'opus'
			end
		end
		i = i + 1
	end
	return ''
end

function M.score2midi(score)
	return M.opus2midi(M.score2opus(score))
end

function M.score2stats(opus_or_score)
--[[ returns a table:
 bank_select (array of 2-element arrays {msb,lsb}),
 channels_by_track (table, by track, of arrays),
 channels_total (array),
 general_midi_mode (array),
 ntracks,
 nticks,
 num_notes_by_channel (table of numbers),
 patch_changes_by_track (table of tables),
 patch_changes_total (array),
 percussion (a dictionary histogram of channel-9 events),
 pitches (dict histogram of pitches on channels other than 9),
 pitch_range_by_track (table, by track, of two-member-arrays),
 pitch_range_sum (sum over tracks of the pitch_ranges)
]]
	local bank_select_msb = -1
	local bank_select_lsb = -1
	local bank_select = {}
	local channels_by_track = {}
	local channels_total    = {}
	local general_midi_mode = {}
	local num_notes_by_channel = {} -- 5.7
	local patches_used_by_track  = {}
	local patches_used_total     = {}
	local patch_changes_by_track = {}
	local patch_changes_total    = {}
	local percussion = {} -- histogram of channel 9 "pitches"
	local pitches    = {} -- histogram of pitch-occurrences channels 0-8,10-15
	local pitch_range_sum = 0   -- u pitch-ranges of each track
	local pitch_range_by_track = {}
	local is_a_score = true
	if opus_or_score == nil then
		return {bank_select={}, channels_by_track={}, channels_total={},
		 general_midi_mode={}, ntracks=0, nticks=0,
		 num_notes_by_channel={},
		 patch_changes_by_track={}, patch_changes_total={},
		 percussion={}, pitches={}, pitch_range_by_track={},
		 ticks_per_quarter=0, pitch_range_sum=0
		}
	end
	local ticks_per_quarter = opus_or_score[1]
	local nticks = 0 -- 4.7
	for i = 2,#opus_or_score do  -- ignore first element, which is ticks
		local highest_pitch = 0  -- 4.7
		local lowest_pitch = 128 -- 4.7
		local channels_this_track = {}      -- 4.7
		local patch_changes_this_track = {} -- 4.7
		for k,event in ipairs(opus_or_score[i]) do
			if event[1] == 'note' then
				num_notes_by_channel[event[4]] = (num_notes_by_channel[event[4]] or 0) + 1
				if event[4] == 9 then
					percussion[event[5]] = (percussion[event[5]] or 0) + 1
				else
					pitches[event[5]]    = (pitches[event[5]] or 0) + 1
					if event[5] > highest_pitch then
						highest_pitch = event[5]
					end
					if event[5] < lowest_pitch then
						lowest_pitch = event[5]
					end
				end
				channels_this_track[event[4]] = true
				channels_total[event[4]] = true
				local finish_time = event[2] + event[3] -- 4.7
				if finish_time > nticks then
					nticks = finish_time
				end
			elseif event[1] == 'note_on' then
				is_a_score = false   -- 4.6
				num_notes_by_channel[event[3]] = (num_notes_by_channel[event[3]] or 0) + 1
				if event[3] == 9 then
					percussion[event[4]] = (percussion[event[4]] or 0) + 1
				else
					pitches[event[4]]    = (pitches[event[4]] or 0) + 1
					if event[4] > highest_pitch then
						highest_pitch = event[4]
					end
					if event[4] < lowest_pitch then
						lowest_pitch = event[4]
					end
				end
				channels_this_track[event[3]] = true
				channels_total[event[3]] = true
			elseif event[1] == 'note_off' then
				local finish_time = event[2] -- 4.7
				if finish_time > nticks then
					nticks = finish_time
				end
			elseif event[1] == 'patch_change' then
				patch_changes_this_track[event[3]] = event[4]
				patch_changes_total[event[4]] = true
			elseif event[1] == 'control_change' then
				if event[4] == 0 then  -- bank select MSB
					bank_select_msb = event[5]
				elseif event[4] == 32 then  -- bank select LSB
					bank_select_lsb = event[5]
				end
				if bank_select_msb >= 0 and bank_select_lsb >= 0 then
					table.insert(bank_select,{bank_select_msb,bank_select_lsb})
					bank_select_msb = -1
					bank_select_lsb = -1
				end
			elseif event[1] == 'sysex_f0' then
				if sysex2midimode[event[3]] then
				table.insert(general_midi_mode,sysex2midimode[event[3]]) -- 5.0
				end
			end
			if is_a_score then
				if event[2] > nticks then
					nticks = event[2]
				end
			else
				nticks = nticks + event[2]
			end
		end
		if lowest_pitch == 128 then
			lowest_pitch = 0
		end
		table.insert(channels_by_track, sorted_keys(channels_this_track))
		table.insert(patch_changes_by_track, patch_changes_this_track) -- 4.2
		table.insert(pitch_range_by_track, {lowest_pitch,highest_pitch})
		pitch_range_sum = pitch_range_sum + highest_pitch - lowest_pitch
		i = i + 1
	end

	return {
		bank_select=bank_select,
		channels_by_track=channels_by_track,
		channels_total=sorted_keys(channels_total),
		general_midi_mode=general_midi_mode,
		ntracks=#opus_or_score-1,
		nticks=nticks,
		num_notes_by_channel=num_notes_by_channel,
		patch_changes_by_track=patch_changes_by_track,
		patch_changes_total=sorted_keys(patch_changes_total),
		percussion=percussion,
		pitches=pitches,
		pitch_range_by_track=pitch_range_by_track,
		pitch_range_sum=pitch_range_sum,
		ticks_per_quarter=ticks_per_quarter
	}
end

function M.segment(...)
	local args = {...}  -- 3.8
	local score, start, endt, tracks = ...
	if #args == 1 and type(args[1][1]) == 'table' then
		score = args[1][1]
		start = args[1]['start_time'] -- 4.1
		endt = args[1]['end_time']    -- 4.1
		tracks = args[1]['tracks']
	end
	if not score == nil or type(score) ~= 'table' or #score < 2 then
		return {1000, {},}
	end
	if not start then start = 0 end -- 4.1
	if not endt  then endt  = 1000000000 end
	if not tracks then tracks = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15} end
	local new_score = {score[1],}
	local my_type = M.score_type(score)
	if my_type == '' then
		return new_score
	end
	if my_type == 'opus' then
		-- more difficult (disconnecting note_on's from their note_off's)...
		warn("segment: opus format is not supported\n")
		clean_up_warnings()
		return new_score
	end
	tracks = dict(tracks)  -- convert list to lookup
	for i = 2,#score do   -- ignore ticks; we count in ticks anyway
		if tracks[i-1] then
			local new_track = {}
			local channel2cc_num  = {} -- recentest controlchange before start
			local channel2cc_val  = {}
			local channel2cc_time = {}
			local channel2patch_num = {} -- recentest patchchange before start
			local channel2patch_time = {}
			local set_tempo_num = 500000 -- recentest tempochange 6.3
			local set_tempo_time = 0
			local earliest_note_time = endt
			for k,event in ipairs(score[i]) do
				if event[1] == 'control_change' then  -- 6.5
					local cc_time = channel2cc_time[event[3]] or 0
					if event[2]<=start and event[2]>=cc_time then
						channel2cc_num[event[3]]  = event[4]
						channel2cc_val[event[3]]  = event[5]
						channel2cc_time[event[3]] = event[2]
					end
				elseif event[1] == 'patch_change' then
					local patch_time = channel2patch_time[event[3]] or 0 -- 4.7
					if event[2]<=start and event[2]>=patch_time then  -- 2.0
						channel2patch_num[event[3]]  = event[4]
						channel2patch_time[event[3]] = event[2]
					end
				elseif event[1] == 'set_tempo' then   -- 6.4 <=start not <start
					if (event[2]<=start) and (event[2]>=set_tempo_time) then
						set_tempo_num  = event[3]
						set_tempo_time = event[2]
					end
				end
				if event[2] >= start and event[2] <= endt then
					new_track[#new_track+1]= event
					if event[1] == 'note' and event[2]<earliest_note_time then
						earliest_note_time = event[2]
					end
				end
			end
			if #new_track > 0 then
				new_track[#new_track+1] = ({'set_tempo', start, set_tempo_num})
				for k,c in ipairs(sorted_keys(channel2patch_num)) do -- 4.3
					new_track[#new_track+1] =
					 ({'patch_change', start, c, channel2patch_num[c]})
				end
				for k,c in ipairs(sorted_keys(channel2cc_num)) do -- 6.5
					new_track[#new_track+1] = ({'control_change', start, c,
					  channel2cc_num[c],  channel2cc_val[c]})
				end
				new_score[#new_score+1] = (new_track)
			end
		end
	end
	clean_up_warnings()
	return new_score
end

function M.timeshift(...)
	local args = {...}  -- 3.8
	local score, shift, start_time, from_time, tracks_array = ...
	if #args == 1 and type(args[1][1]) == 'table' then
		score = args[1][1]
		shift = args[1]['shift']
		start_time = args[1]['start_time']
		from_time = args[1]['from_time']
		tracks_array = args[1]['tracks']
	end
	if score == nil or #score < 2 then return {1000, {},} end
	if from_time == nil then from_time = 0 end
	if not tracks_array then
		tracks_array = {0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15}
	end
	local new_score = {score[1],}
	local my_type = M.score_type(score)
	if my_type == '' then return new_score end
	if my_type == 'opus' then
		warn("timeshift: opus format is not supported\n")
		clean_up_warnings()
		return new_score
	end
	if shift ~= nil and start_time ~= nil then
		warn("timeshift: shift and start_time specified: ignoring shift\n")
		shift = nil
	end
	if shift == nil then
		if start_time == nil or start_time < 0 then
			start_time = 0
		end
		-- shift = start_time - from_time
	end

	local tracks = dict(tracks_array)  -- convert list to lookup
	local earliest = 1000000000
	if start_time ~= nil or shift < 0 then -- find the earliest event
		for i = 2,#score do   -- ignore first element (ticks)
			if tracks[i-1] then
				for k,event in ipairs(score[i]) do
					local continue2 = false
					if event[2] < from_time then
						-- just inspect the to_be_shifted events
						continue2 = true
					end
					if not continue2 then
						if event[2] < earliest then
							earliest = event[2]
						end
					end
				end
			end
		end
	end
	if earliest > 999999999 then
		earliest = 0
	end
	if shift == nil then
		shift = start_time - earliest
	elseif (earliest + shift) < 0 then
		start_time = 0
		shift = 0 - earliest
	end

	local i = 2   -- ignore first element (ticks) -- 4.7
	while i <= #score do
		if not tracks[i-1] then
			new_score[#new_score+1] = deepcopy(score[i])
			i = i + 1
		else
			local new_track = {} -- 4.7
			for k,event in ipairs(score[i]) do
				local continue = false
				local new_event = copy(event) -- 4.7
				if new_event[2] >= from_time then
					-- 4.1 must not rightshift set_tempo
					if new_event[1] ~= 'set_tempo' or shift<0 then
						new_event[2] = new_event[2] + shift
					end
				elseif (shift < 0) and (new_event[2] >= (from_time+shift)) then
					continue = true
				end
				if not continue then
					new_track[#new_track+1] = new_event
				end
			end
			if #new_track > 0 then
				new_score[#new_score+1] = new_track
			end
			i = i + 1
		end
	end
	clean_up_warnings()
	return new_score
end

function M.to_millisecs(old_opus)   -- 6.7
	if old_opus == nil then return {1000,{},}; end
	local old_tpq  = old_opus[1]
	local new_opus = {1000,}
	-- 6.7 first go through building a dict of set_tempos by absolute-tick
	local ticks2tempo = {}
	local itrack = 2
	while itrack <= #old_opus do
		local ticks_so_far = 0
		local k; for k,old_event in ipairs(old_opus[itrack]) do
			if old_event[1] == 'note' then
				warn('to_millisecs needs an opus, not a score')
				clean_up_warnings()
				return {1000,{},}
			end
			ticks_so_far = ticks_so_far + old_event[2]
			if old_event[1] == 'set_tempo' then
				ticks2tempo[ticks_so_far] = old_event[3]
			end
		end
		itrack = itrack + 1
	end
	--  then get the sorted-array of their keys
	local tempo_ticks = sorted_keys(ticks2tempo)
	--  then go through converting to millisec, testing if the next
	--  set_tempo lies before the next track-event, and using it if so.
	local itrack = 2
	while itrack <= #old_opus do
		local ms_per_old_tick = 500.0 / old_tpq -- will be rounded later 6.3
		local i_tempo_ticks = 1
		local ticks_so_far = 0
		local ms_so_far = 0.0
		local previous_ms_so_far = 0.0
		local new_track = {{'set_tempo',0,1000000},}  -- new "crochet" is 1 sec
		local k; for k,old_event in ipairs(old_opus[itrack]) do
			-- detect if ticks2tempo has something before this event
			-- If ticks2tempo is at the same time, don't handle it yet.
			local event_delta_ticks = old_event[2]
			if i_tempo_ticks <= #tempo_ticks and
			  tempo_ticks[i_tempo_ticks] < (ticks_so_far + old_event[2]) then
				local delta_ticks = tempo_ticks[i_tempo_ticks] - ticks_so_far
				ms_so_far = ms_so_far + (ms_per_old_tick * delta_ticks)
				ticks_so_far = tempo_ticks[i_tempo_ticks]
				ms_per_old_tick = ticks2tempo[ticks_so_far] / (1000.0*old_tpq)
				i_tempo_ticks = i_tempo_ticks + 1
				event_delta_ticks = event_delta_ticks - delta_ticks
			end  -- now handle the new event
			local new_event = copy(old_event) -- 4.7
			ms_so_far = ms_so_far + (ms_per_old_tick * old_event[2])  -- NO!
			new_event[2] = math.floor(0.5 + ms_so_far - previous_ms_so_far)
			if old_event[1] ~= 'set_tempo' then -- set_tempos are already known
				previous_ms_so_far = ms_so_far
				new_track[#new_track+1] = new_event
			end
			ticks_so_far = ticks_so_far + event_delta_ticks
		end
		new_opus[#new_opus+1] = new_track
		itrack = itrack + 1
	end
	clean_up_warnings()
	return new_opus
end

return M

-- http://lua-users.org/wiki/ModuleDefinition
-- http://lua-users.org/wiki/LuaModuleFunctionCritiqued
--[=[

=pod

=head1 NAME

MIDI.lua - Reading, writing and manipulating MIDI data

=head1 SYNOPSIS

 local MIDI = require 'MIDI'

 local my_score = {
    96,  -- ticks per beat
    {    -- first track
        {'patch_change', 0, 1, 8},
        {'note', 5, 96, 1, 25, 96},
        {'note', 101, 96, 1, 29, 96},
    },  -- end of first track
 }

 -- Going through a score within a Lua program...
 channels = {[2]=true, [3]=true, [5]=true, [8]=true, [13]=true}
 for itrack = 2,#my_score do  -- skip 1st element, which is ticks
    for k,event in ipairs(my_score[itrack]) do
       if event[1] == 'note' then
          -- for example, do something to all notes
       end
       -- to work on events in only particular channels...
       channelindex = MIDI.Event2channelindex[event[1]]
       if channelindex and channels[event[channelindex]] then
          -- do something to channels 2,3,5,8 and 13
       end
    end
 end

 local midifile = assert(io.open('f.mid','w'))
 midifile:write(MIDI.score2midi(my_score))
 midifile:close()

=head1 DESCRIPTION

This module offers functions:  concatenate_scores(), grep(),
merge_scores(), mix_scores(), midi2opus(), midi2score(), opus2midi(),
opus2score(), play_score(), score2midi(), score2opus(), score2stats(),
score_type(), segment(), timeshift() and to_millisecs(),
where "midi" means the MIDI-file bytes (as can be put in a .mid file,
or piped into aplaymidi), and "opus" and "score" are list-structures
as inspired by Sean Burke's MIDI-Perl CPAN module.

The "opus" is a direct translation of the midi-file-events, where
the times are delta-times, in ticks, since the previous event:

 {'note_on',  dtime, channel, note, velocity}       -- in an "opus"
 {'note_off', dtime, channel, note, velocity}       -- in an "opus"

The "score" is more human-centric; it uses absolute times, and
combines the separate note_on and note_off events into one "note"
event, with a duration:

 {'note', start_time, duration, channel, note, velocity} -- in a "score"

MIDI.lua is a call-compatible translation into Lua of the Python module
http://www.pjb.com.au/midi/free/MIDI.py ;
see http://www.pjb.com.au/midi/MIDI.html

=head1 FUNCTIONS

=over 3

=item I<concatenate_scores> (array_of_scores)

Concatenates an array of scores into one score.
If the scores differ in their "ticks" parameter,
they will all get converted to millisecond-tick format.

=item I<grep> (score, channels)

Returns a "score" containing only the channels specified.
(It also works on an "opus", but because of the
incremental times the result will usually be useless.)
The second parameter is an array of the wanted channel numbers,
for example:

 channels = {0, 4,}

=item I<merge_scores> (array_of_scores)

Merges an array of scores into one score.  A merged score comprises
all of the tracks from all of the input scores; un-merging is possible
by selecting just some of the tracks.
If the scores differ in their "ticks" parameter,
they will all get converted to millisecond-tick format.
merge_scores attempts to resolve channel-conflicts,
but there are of course only 15 available channels...

=item I<mix_opus_tracks> (tracks)

Mixes an array of opus tracks into one track.
A mixed track cannot be un-mixed.
It is assumed that the tracks share the same I<ticks> parameter
and the same tempo.
Mixing score-tracks is trivial (just insert all the events into one array).
Mixing opus-tracks is only slightly harder,
but it's common enough that a dedicated function is useful.

=item I<mix_scores> (array_of_scores)

Mixes an array of scores into one one-track score.
A mixed score cannot be un-mixed.
Hopefully the scores have no undesirable channel conflicts between them...
If the scores differ in their "ticks" parameter,
they will all get converted to millisecond-tick format.


=item I<midi2ms_score> (midi_in_string_form)

Translates MIDI into a "score" with one beat per second and one
tick per millisecond, using midi2opus() then to_millisecs()
then opus2score()

=item I<midi2opus> (midi_in_string_form)

Translates MIDI into an "opus".  For a description of the
"opus" format, see opus2midi()

=item I<midi2score> (midi_in_string_form)

Translates MIDI into a "score", using midi2opus() then opus2score()


=item I<opus2midi> (an_opus)

The argument is an array: the first item in the list is the "ticks"
parameter, the others are the tracks. Each track is an array of
midi-events, and each event is itself an array; see EVENTS below.
opus2midi() returns a string of the MIDI, which can then be
written to a .mid file, or to stdout.

 local MIDI = require 'MIDI'
 my_opus = {
    96, -- MIDI-ticks per beat
    {   -- first track:
        {'patch_change', 0, 1, 8},   -- and these are the events...
        {'set_tempo', 0, 750000},    -- microseconds per beat
        {'note_on', 5, 1, 25, 96},
        {'note_off', 96, 1, 25, 0},
        {'note_on', 0, 1, 29, 96},
        {'note_off', 96, 1, 29, 0},
    },  -- end of first track
 }
 local my_midi = MIDI.opus2midi(my_opus)
 io.write(my_midi)  -- can be saved in o.mid or piped into "aplaymidi -"

=item I<opus2score> (an_opus)

For a description of the "opus" and "score" formats,
see opus2midi() and score2opus().

The score track is returned sorted by the end-times of the notes,
so if you need it sorted by their start-times you have to do that yourself:

  table.sort(score[itrack], function (e1,e2) return e1[2]<e2[2] end)

=item I<play_score> (opus_or_score)

Converts the "score" to midi, and feeds it into 'aplaymidi -'.
If Lua's I<posix> module is installed, the aplaymidi process will
be run in the background.

=item I<score_type> (opus_or_score)

Returns a string, either 'opus' or 'score' or ''

=item I<score2midi> (a_score)

Translates a "score" into MIDI, using score2opus() then opus2midi()

=item I<score2opus> (a_score)

The argument is an array: the first item in the list is the "ticks"
parameter, the others are the tracks. Each track is an array
of score-events, and each event is itself an array.
score2opus() returns an array specifying the equivalent "opus".
A score-event is similar to an opus-event (see above),
except that in a score:

1) all times are expressed as an absolute number of ticks
    from the track's start time

2) the pairs of 'note_on' and 'note_off' events in an "opus"
    are abstracted into a single 'note' event in a "score"

 {'note', start_time, duration, channel, pitch, velocity}

 my_score = {
    96,
    {   -- first track
        {'patch_change', 0, 1, 8},
        {'note', 5, 96, 1, 25, 96},
        {'note', 101, 96, 1, 29, 96},
    },  -- end of first track
 }
 my_opus = score2opus(my_score)

=item I<score2stats> (opus_or_score)

Returns a table of some basic stats about the score, like:

 bank_select (array of 2-element arrays {msb,lsb}),
 channels_by_track (table, by track, of arrays),
 channels_total (array),
 general_midi_mode (array),
 ntracks,
 nticks,
 num_notes_by_channel (table of numbers)
 patch_changes_by_track (table of arrays),
 patch_changes_total (array),
 percussion (a dictionary histogram of channel-9 events),
 pitches (dict histogram of pitches on channels other than 9),
 pitch_range_by_track (table, by track, of two-member-arrays),
 pitch_range_sum (sum over tracks of the pitch_ranges)

=item I<segment> (score, start_time, end_time, tracks)

=item I<segment> {score, start_time=100, end_time=2000, tracks={3,4,5}}

Returns a "score" which is a segment of the one supplied
as the argument, beginning at "start_time" ticks and ending
at "end_time" ticks (or at the end if "end_time" is not supplied).
If the array "tracks" is specified, only those tracks will be returned.

=item I<timeshift> (score, shift, start_time, from_time, tracks)

=item I<timeshift> {score, shift=50, start_time=nil, from_time=2000, tracks={2,3}}

Returns a "score" shifted in time by "shift" ticks, or shifted
so that the first event starts at "start_time" ticks.

If "from_time" is specified, only those events in the score
that begin after it are shifted. If "start_time" is less than
"from_time" (or "shift" is negative), then the intermediate
notes are deleted, though patch-change events are preserved.

If "tracks" are specified, then only those tracks (0 to 15) get shifted.
"tracks" should be an array.

It is deprecated to specify both "shift" and "start_time".
If this does happen, timeshift() will print a warning to
stderr and ignore the "shift" argument.

If "shift" is negative and sufficiently large that it would
leave some event with a negative tick-value, then the score
is shifted so that the first event occurs at time 0. This
also occurs if "start_time" is negative, and is also the
default if neither "shift" nor "start_time" are specified.

=item I<to_millisecs> (an_opus)

Recallibrates all the times in an "opus" to use one beat
per second and one tick per millisecond.  This makes it
hard to retrieve any information about beats or barlines,
but it does make it easy to mix different scores together.

=back

=head1 EVENTS

The "opus" is a direct translation of the midi-file-events, where
the times are delta-times, in ticks, since the previous event.

 {'note_on',  dtime, channel, note, velocity}       -- in an "opus"
 {'note_off', dtime, channel, note, velocity}       -- in an "opus"

The "score" is more human-centric; it uses absolute times, and
combines the separate note_on and note_off events into one "note"
event, with a duration:

 {'note', start_time, duration, channel, note, velocity} -- in a "score"

Events (in an "opus" structure):

 {'note_off', dtime, channel, note, velocity}       -- in an "opus"
 {'note_on',  dtime, channel, note, velocity}       -- in an "opus"
 {'key_after_touch', dtime, channel, note, velocity}
 {'control_change', dtime, channel, controller(0-127), value(0-127)}
 {'patch_change', dtime, channel, patch}
 {'channel_after_touch', dtime, channel, velocity}
 {'pitch_wheel_change', dtime, channel, pitch_wheel}
 {'text_event', dtime, text}
 {'copyright_text_event', dtime, text}
 {'track_name', dtime, text}
 {'instrument_name', dtime, text}
 {'lyric', dtime, text}
 {'marker', dtime, text}
 {'cue_point', dtime, text}
 {'text_event_08', dtime, text}
 {'text_event_09', dtime, text}
 {'text_event_0a', dtime, text}
 {'text_event_0b', dtime, text}
 {'text_event_0c', dtime, text}
 {'text_event_0d', dtime, text}
 {'text_event_0e', dtime, text}
 {'text_event_0f', dtime, text}
 {'end_track', dtime}
 {'set_tempo', dtime, tempo}
 {'smpte_offset', dtime, hr, mn, se, fr, ff}
 {'time_signature', dtime, nn, dd, cc, bb}
 {'key_signature', dtime, sf, mi}
 {'sequencer_specific', dtime, raw}
 {'raw_meta_event', dtime, command(0-255), raw}
 {'sysex_f0', dtime, raw}
 {'sysex_f7', dtime, raw}
 {'song_position', dtime, song_pos}
 {'song_select', dtime, song_number}
 {'tune_request', dtime}

=head1 DATA TYPES

 channel = a value 0 to 15
 controller = 0 to 127 (see http://www.pjb.com.au/muscript/gm.html#cc)
 dtime = time measured in "ticks", 0 to 268435455
 velocity = a value 0 (soft) to 127 (loud)
 note = a value 0 to 127  (middle-C is 60)
 patch = 0 to 127 (see http://www.pjb.com.au/muscript/gm.html )
 pitch_wheel = a value -8192 to 8191 (0x1FFF)
 raw = 0 or more bytes of binary data
 sequence_number = a value 0 to 65,535 (0xFFFF)
 song_pos = a value 0 to 16,383 (0x3FFF)
 song_number = a value 0 to 127
 tempo = microseconds per crochet (quarter-note), 0 to 16777215
 text = a string of 0 or more bytes of of ASCII text
 ticks = the number of ticks per crochet (quarter-note)

In I<sysex_f0> events, the I<raw> data must not start with a \xF0
byte, since this gets added automatically;
but it must end with an explicit \xF7 byte!
In the very unlikely case that you ever need to split I<sysex> data
into one I<sysex_f0> followed by one or more I<sysex_f7>s, then
only the last of those I<sysex_f7> events must end with the explicit \xF7
byte (again, the I<raw> data of individual I<sysex_f7> events
must not start with any \xF7 byte, since this gets added automatically).

=head1 PUBLIC-ACCESS TABLES

=over 3

=item I<Number2patch>

In this table the index is the patch-number (0 to 127),
and the value is its corresponding General-MIDI Patch
(on Channels other than 9).
See: http://www.pjb.com.au/muscript/gm.html#patch

=item I<Notenum2percussion>

In this table the index is the note-number (35 to 81),
and the value is its corresponding General-MIDI Percussion instrument
(on Channel 9).  See: http://www.pjb.com.au/muscript/gm.html#perc

=item I<Event2channelindex>

In this table the index is the event-name (see EVENTS),
and the value is the position within the event-array
at which the I<Channel-number> occurs.
It is very useful for manipulating particular channels
within a score (see SYNOPSIS)

=back

=head1 DOWNLOAD

This module is available as a LuaRock in
http://luarocks.org/modules/peterbillam
so you should be able to install it with the command:
B<sudo luarocks install midi>

The source is in
http://www.pjb.com.au/comp/lua/MIDI.lua
for you to install by hand in your LUA_PATH

The test script used during development is
http://www.pjb.com.au/comp/lua/test_mi.lua
which requires the DataDumper module.

You should be able to install the luaposix module with:
B<sudo luarocks install luaposix>

=head1 AUTHOR

Peter J Billam, http://www.pjb.com.au/comp/contact.html

=head1 SEE ALSO

 http://www.pjb.com.au/
 http://www.pjb.com.au/comp/index.html#lua
 http://www.pjb.com.au/comp/lua/MIDI.html
 http://www.pjb.com.au/midi/MIDI.html
 http://www.pjb.com.au/muscript/gm.html

=cut

]=]
