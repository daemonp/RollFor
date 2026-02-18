RollFor = RollFor or {}
local m = RollFor

if m.LootTracker then return end

local M = {}
local getn = m.getn

---@class LootEvent
---@field type "winner"|"award"|"trade"
---@field timestamp number
---@field item_id number
---@field item_link string?
---@field item_name string?
---@field quality number?
---@field from_player string?
---@field from_player_class string?
---@field to_player string
---@field to_player_class string?
---@field roll_type string?
---@field rolling_strategy string?
---@field winning_roll number?
---@field sr_plus number?

---@class LootTracker
---@field record_winner fun( player_name: string, player_class: string?, item_id: number, item_link: string, roll_type: string?, rolling_strategy: string?, winning_roll: number?, sr_plus: number? )
---@field record_award fun( player_name: string, player_class: string?, item_id: number, item_link: string, roll_type: string?, rolling_strategy: string?, winning_roll: number?, sr_plus: number? )
---@field record_trade fun( from_player: string, to_player: string, item_id: number, item_name: string?, quality: number? )
---@field has_winner fun( item_link: string ): boolean
---@field get_events fun(): LootEvent[]
---@field clear fun()

---@param db table
---@param group_roster GroupRoster
---@return LootTracker
function M.new( db, group_roster )
  db.events = db.events or {}

  local function resolve_item_info( item_id )
    local quality = m.get_item_quality_and_texture( m.api, item_id )
    local item_name = m.api.GetItemInfo( item_id )
    return item_name, quality
  end

  local function record_winner( player_name, player_class, item_id, item_link, roll_type, rolling_strategy, winning_roll, sr_plus )
    local item_name, quality = resolve_item_info( item_id )

    table.insert( db.events, {
      type = "winner",
      timestamp = m.lua.time(),
      item_id = item_id,
      item_link = item_link,
      item_name = item_name,
      quality = quality,
      to_player = player_name,
      to_player_class = player_class,
      roll_type = roll_type,
      rolling_strategy = rolling_strategy,
      winning_roll = winning_roll,
      sr_plus = sr_plus
    } )
  end

  local function record_award( player_name, player_class, item_id, item_link, roll_type, rolling_strategy, winning_roll, sr_plus )
    local item_name, quality = resolve_item_info( item_id )

    table.insert( db.events, {
      type = "award",
      timestamp = m.lua.time(),
      item_id = item_id,
      item_link = item_link,
      item_name = item_name,
      quality = quality,
      to_player = player_name,
      to_player_class = player_class,
      roll_type = roll_type,
      rolling_strategy = rolling_strategy,
      winning_roll = winning_roll,
      sr_plus = sr_plus
    } )
  end

  local function record_trade( from_player, to_player, item_id, item_name, quality )
    local from = group_roster.find_player( from_player )
    local to = group_roster.find_player( to_player )

    table.insert( db.events, {
      type = "trade",
      timestamp = m.lua.time(),
      item_id = item_id,
      item_name = item_name,
      quality = quality,
      from_player = from_player,
      from_player_class = from and from.class,
      to_player = to_player,
      to_player_class = to and to.class
    } )
  end

  local function has_winner( item_link )
    if not item_link then return false end

    for i = 1, getn( db.events ) do
      local event = db.events[ i ]
      if event.type == "winner" and event.item_link == item_link then
        return true
      end
    end

    return false
  end

  local function get_events()
    return db.events
  end

  local function clear()
    if getn( db.events ) == 0 then return end
    m.clear_table( db.events )
  end

  ---@type LootTracker
  return {
    record_winner = record_winner,
    record_award = record_award,
    record_trade = record_trade,
    has_winner = has_winner,
    get_events = get_events,
    clear = clear
  }
end

m.LootTracker = M
return M
