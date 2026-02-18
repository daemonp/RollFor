RollFor = RollFor or {}
local m = RollFor

if m.RosterTracker then return end

local M = {}
local getn = m.getn

---@class RosterEvent
---@field type "join"|"leave"|"snapshot"
---@field timestamp number
---@field player_name string?
---@field player_class string?
---@field reason string?
---@field trigger string?
---@field players table[]?

---@class RosterTracker
---@field on_group_changed fun()
---@field take_snapshot fun( trigger: string )
---@field record_softres_signups fun( softres: SoftRes )
---@field get_events fun(): RosterEvent[]
---@field get_signups fun(): table[]
---@field clear fun()

---@param db table
---@param group_roster GroupRoster
---@return RosterTracker
function M.new( db, group_roster )
  db.events = db.events or {}
  db.signups = db.signups or {}

  local last_roster = {}

  local function build_roster_map( players )
    local map = {}
    for i = 1, getn( players ) do
      local p = players[ i ]
      map[ p.name ] = p
    end
    return map
  end

  local function initialize_last_roster()
    if group_roster.am_i_in_group() then
      local players = group_roster.get_all_players_in_my_group()
      last_roster = build_roster_map( players )
    end
  end

  local function take_snapshot( trigger )
    local players = group_roster.get_all_players_in_my_group()
    local snapshot_players = {}

    for i = 1, getn( players ) do
      local p = players[ i ]
      table.insert( snapshot_players, {
        name = p.name,
        class = p.class,
        online = p.online and true or false
      } )
    end

    table.insert( db.events, {
      type = "snapshot",
      timestamp = m.lua.time(),
      trigger = trigger,
      players = snapshot_players
    } )

    last_roster = build_roster_map( players )
  end

  local function on_group_changed()
    if not group_roster.am_i_in_group() then
      last_roster = {}
      return
    end

    local current_players = group_roster.get_all_players_in_my_group()
    local current_map = build_roster_map( current_players )

    -- Detect joins: in current but not in last
    for i = 1, getn( current_players ) do
      local p = current_players[ i ]
      if not last_roster[ p.name ] then
        table.insert( db.events, {
          type = "join",
          timestamp = m.lua.time(),
          player_name = p.name,
          player_class = p.class
        } )
      end
    end

    -- Detect leaves: in last but not in current
    for name, p in pairs( last_roster ) do
      if not current_map[ name ] then
        table.insert( db.events, {
          type = "leave",
          timestamp = m.lua.time(),
          player_name = name,
          player_class = p.class,
          reason = "left"
        } )
      end
    end

    last_roster = current_map
  end

  local function record_softres_signups( softres )
    m.clear_table( db.signups )

    local rollers = softres.get_all_rollers()

    for i = 1, getn( rollers ) do
      local roller = rollers[ i ]
      local items = {}

      local item_ids = softres.get_item_ids()
      for j = 1, getn( item_ids ) do
        local item_id = item_ids[ j ]
        if softres.is_player_softressing( roller.name, item_id ) then
          table.insert( items, item_id )
        end
      end

      table.insert( db.signups, {
        name = roller.name,
        items = items
      } )
    end
  end

  local function get_events()
    return db.events
  end

  local function get_signups()
    return db.signups
  end

  local function clear()
    if getn( db.events ) == 0 and getn( db.signups ) == 0 then return end
    m.clear_table( db.events )
    m.clear_table( db.signups )
    last_roster = {}
  end

  initialize_last_roster()

  ---@type RosterTracker
  return {
    on_group_changed = on_group_changed,
    take_snapshot = take_snapshot,
    record_softres_signups = record_softres_signups,
    get_events = get_events,
    get_signups = get_signups,
    clear = clear
  }
end

m.RosterTracker = M
return M
