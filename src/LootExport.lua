RollFor = RollFor or {}
local m = RollFor

if m.LootExport then return end

local M = {}
local getn = m.getn

---@diagnostic disable-next-line: undefined-global
local lib_stub = LibStub

---@class LootExport
---@field export fun(): string?
---@field get_data fun(): table

---@param loot_tracker LootTracker
---@param version table
---@param get_raid_id fun(): string?
---@return LootExport
function M.new( loot_tracker, version, get_raid_id )
  -- Items are keyed by item_link, which is unique per drop instance in WoW
  -- (even for duplicate drops like 2x tier tokens). Winner/award events receive
  -- the actual drop's item_link from winner_tracker/loot callback, not a
  -- reconstructed one, so duplicates are tracked independently.
  local function build_loot_table( events )
    local items = {}
    local item_order = {}

    for i = 1, getn( events ) do
      local event = events[ i ]

      if event.type == "winner" then
        local key = event.item_link
        items[ key ] = items[ key ] or {}
        items[ key ].item_id = event.item_id
        items[ key ].item_link = event.item_link
        items[ key ].item_name = items[ key ].item_name or event.item_name
        items[ key ].quality = items[ key ].quality or event.quality
        items[ key ].original_winner = {
          name = event.to_player,
          class = event.to_player_class,
          roll_type = event.roll_type,
          rolling_strategy = event.rolling_strategy,
          winning_roll = event.winning_roll,
          sr_plus = event.sr_plus
        }

        if not items[ key ].order then
          items[ key ].order = getn( item_order ) + 1
          table.insert( item_order, key )
        end
      elseif event.type == "award" then
        local key = event.item_link
        items[ key ] = items[ key ] or {}

        if not items[ key ].original_winner then
          items[ key ].item_id = event.item_id
          items[ key ].item_link = event.item_link
          items[ key ].item_name = items[ key ].item_name or event.item_name
          items[ key ].quality = items[ key ].quality or event.quality
          items[ key ].original_winner = {
            name = event.to_player,
            class = event.to_player_class,
            roll_type = event.roll_type,
            rolling_strategy = event.rolling_strategy,
            winning_roll = event.winning_roll,
            sr_plus = event.sr_plus
          }
        end

        if not items[ key ].order then
          items[ key ].order = getn( item_order ) + 1
          table.insert( item_order, key )
        end
      elseif event.type == "trade" then
        -- Use item_order for deterministic iteration (pairs() order is undefined).
        -- Prefer items not yet traded so duplicate drops (same item_id, same winner)
        -- match independently.
        local found_key
        local fallback_key
        for j = 1, getn( item_order ) do
          local key = item_order[ j ]
          local item = items[ key ]
          if item.item_id == event.item_id then
            local last = item.final_recipient or item.original_winner
            if last and last.name == event.from_player then
              if not item.traded then
                found_key = key
                break
              elseif not fallback_key then
                fallback_key = key
              end
            end
          end
        end
        found_key = found_key or fallback_key

        if found_key then
          items[ found_key ].final_recipient = {
            name = event.to_player,
            class = event.to_player_class
          }
          items[ found_key ].traded = true
          items[ found_key ].item_name = items[ found_key ].item_name or event.item_name
          items[ found_key ].quality = items[ found_key ].quality or event.quality
        end
      end
    end

    return items, item_order
  end

  local function get_data()
    local events = loot_tracker.get_events()
    if getn( events ) == 0 then return nil end

    local items, item_order = build_loot_table( events )
    local loot = {}

    for i = 1, getn( item_order ) do
      local key = item_order[ i ]
      local item = items[ key ]

      if item.original_winner then
        local entry = {
          item_id = item.item_id,
          item_name = item.item_name,
          quality = item.quality,
          original_winner = item.original_winner,
          final_recipient = item.final_recipient or {
            name = item.original_winner.name,
            class = item.original_winner.class
          },
          traded = item.traded or false
        }

        table.insert( loot, entry )
      end
    end

    return {
      metadata = {
        id = get_raid_id(),
        addon_version = version.str,
        exported_at = m.lua.time(),
        origin = "rollfor"
      },
      loot = loot
    }
  end

  local function export()
    local data = get_data()
    if not data then return nil end

    local saved_huge = math.huge
    math.huge = 1e99
    local json = lib_stub( "Json-0.1.2" )
    local success, json_data = pcall( function() return json.encode( data ) end )
    math.huge = saved_huge

    if not success or not json_data then return nil end

    return m.encode_base64( json_data )
  end

  ---@type LootExport
  return {
    export = export,
    get_data = get_data
  }
end

m.LootExport = M
return M
