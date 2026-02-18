RollFor = RollFor or {}
local m = RollFor

if m.LootExportGui then return end

local M = {}

---@diagnostic disable-next-line: undefined-global
local UIParent = UIParent
---@diagnostic disable-next-line: undefined-global
local ChatFontNormal = ChatFontNormal

local frame_backdrop = {
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

local control_backdrop = {
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

local function create_frame( api )
  local frame = m.create_backdrop_frame( api(), "Frame", "RollForLootExportFrame", UIParent )
  frame:Hide()
  frame:SetWidth( 565 )
  frame:SetHeight( 300 )
  frame:SetPoint( "CENTER", UIParent, "CENTER", 0, 0 )
  frame:EnableMouse()
  frame:SetMovable( true )
  frame:SetResizable( true )
  frame:SetFrameStrata( "DIALOG" )

  frame:SetBackdrop( frame_backdrop )
  frame:SetBackdropColor( 0, 0, 0, 1 )

  frame:SetMinResize( 400, 200 )
  frame:SetToplevel( true )

  local backdrop = m.create_backdrop_frame( api(), "Frame", nil, frame )
  backdrop:SetBackdrop( control_backdrop )
  backdrop:SetBackdropColor( 0, 0, 0 )
  backdrop:SetBackdropBorderColor( 0.4, 0.4, 0.4 )

  backdrop:SetPoint( "TOPLEFT", frame, "TOPLEFT", 17, -18 )
  backdrop:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -17, 43 )

  local scroll_frame = api().CreateFrame( "ScrollFrame", "RollForLootExport@ScrollFrame", backdrop, "UIPanelScrollFrameTemplate" )
  scroll_frame:SetPoint( "TOPLEFT", 5, -6 )
  scroll_frame:SetPoint( "BOTTOMRIGHT", -28, 6 )
  scroll_frame:EnableMouse( true )

  local scroll_child = api().CreateFrame( "Frame", nil, scroll_frame )
  scroll_frame:SetScrollChild( scroll_child )
  scroll_child:SetHeight( 2 )
  scroll_child:SetWidth( 2 )

  local editbox = api().CreateFrame( "EditBox", nil, scroll_child )
  editbox:SetPoint( "TOPLEFT", 0, 0 )
  editbox:SetHeight( 50 )
  editbox:SetWidth( 50 )
  editbox:SetMultiLine( true )
  editbox:SetTextInsets( 5, 5, 3, 3 )
  editbox:EnableMouse( true )
  editbox:SetAutoFocus( false )
  editbox:SetFontObject( ChatFontNormal )
  frame.editbox = editbox

  editbox:SetScript( "OnEscapePressed", function() frame:Hide() end )
  scroll_frame:SetScript( "OnMouseUp", function() editbox:SetFocus() end )

  local function fix_size()
    scroll_child:SetHeight( scroll_frame:GetHeight() )
    scroll_child:SetWidth( scroll_frame:GetWidth() )
    editbox:SetWidth( scroll_frame:GetWidth() )
  end

  scroll_frame:SetScript( "OnShow", fix_size )
  scroll_frame:SetScript( "OnSizeChanged", fix_size )

  -- Guard against accidental edits: reset text if the user modifies it.
  -- We can't use Disable() because that prevents text selection in Vanilla.
  local expected_text = ""
  editbox:SetScript( "OnTextChanged", function()
    scroll_frame:UpdateScrollChildRect()
    if editbox:GetText() ~= expected_text then
      editbox:SetText( expected_text )
      editbox:HighlightText()
    end
  end )
  frame.set_expected_text = function( text )
    expected_text = text
  end

  local close_button = api().CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
  close_button:SetScript( "OnClick", function() frame:Hide() end )
  close_button:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -27, 17 )
  close_button:SetHeight( 20 )
  close_button:SetWidth( 80 )
  close_button:SetText( "Close" )

  local label = frame:CreateFontString( nil, "OVERLAY", "GameFontNormal" )
  label:SetPoint( "BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 22 )
  label:SetTextColor( 1, 1, 1, 1 )
  label:SetText( string.format( "%s      %s", m.colors.blue( "RollFor" ), m.colors.hl( "loot export" ) ) )

  ---@diagnostic disable-next-line: undefined-global
  table.insert( UISpecialFrames, "RollForLootExportFrame" )
  return frame
end

---@class LootExportGui
---@field show fun( text: string )
---@field hide fun()

---@param api fun(): table
---@return LootExportGui
function M.new( api )
  local frame

  local function show( text )
    if not frame then frame = create_frame( api ) end

    frame.set_expected_text( text or "" )
    frame.editbox:SetText( text or "" )
    frame:Show()
    frame.editbox:HighlightText()
    frame.editbox:SetFocus()
  end

  local function hide()
    if frame then frame:Hide() end
  end

  ---@type LootExportGui
  return {
    show = show,
    hide = hide
  }
end

m.LootExportGui = M
return M
