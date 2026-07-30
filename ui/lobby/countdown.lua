-- One face-down deck-back tile (the deck's back sprite + its name), built with the same
-- bypass_back Card pattern as the lobby player cards. `ref` is a deck name/center key, OR
-- an always_draft gamemode's raw ban-pick survivor item ({key=..., stake=...} for Seed
-- Scout, {key='b_challenge', challenge_name=...} for Challenge, etc.) -- SPDRN.resolve_back_key
-- only understands plain strings, so a table ref's own .key is unwrapped here first; without
-- that, resolve_back_key silently returns nil for every table ref and every drafted deck fell
-- back to the hardcoded default below, showing a plain Red Deck regardless of what was
-- actually drafted. `decorate`, if given, is the gamemode's own ban_pick.decorate_tile
-- (stake sticker, challenge-name label, ...) -- called with the RAW ref/item, same contract
-- ban_pick.lua's own deck_tile uses, so the countdown tile ends up decorated exactly like its
-- ban-pick tile was, not just deck-art-correct but stake/challenge-label-correct too.
local function deck_back_tile(ref, decorate)
	local ref_key = (type(ref) == 'table' and ref.key) or ref
	local key = SPDRN.resolve_back_key(ref_key) or 'b_red'
	local center = G.P_CENTERS[key]
	local name = (center and center.name) or key
	local area = CardArea(G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2, G.ROOM.T.h, G.CARD_W, G.CARD_H, { card_limit = 1, type = 'title', highlight_limit = 0, collection = true })
	local card = Card(area.T.x + area.T.w / 2, area.T.y, G.CARD_W, G.CARD_H, nil, G.P_CENTERS['j_joker'], { bypass_back = center.pos })
	card.no_ui = true
	card.states.drag.can = false
	card:flip()
	area:emplace(card, nil, true)
	if decorate then
		decorate(card, ref)
	end
	return { n = G.UIT.C, config = { align = 'cm', padding = 0.12 }, nodes = {
		{ n = G.UIT.R, config = { align = 'cm' }, nodes = { { n = G.UIT.O, config = { object = area } } } },
		{ n = G.UIT.R, config = { align = 'cm', padding = 0.04 }, nodes = {
			{ n = G.UIT.T, config = { text = name, scale = 0.3, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
		} },
	} }
end

-- A row of deck-back tiles for the countdown overlay. `decks` is a single deck ref or an
-- ordered list (e.g. the ban-pick survivors, one run each).
local function deck_backs_row(decks, decorate)
	local refs = type(decks) == 'table' and decks or { decks }
	local cols = {}
	for _, ref in ipairs(refs) do
		cols[#cols + 1] = deck_back_tile(ref, decorate)
	end
	return { n = G.UIT.R, config = { align = 'cm', padding = 0.1 }, nodes = cols }
end

-- 5s synced countdown overlay, then on_complete(). Used for private + matchmaking starts
-- (practice skips it and calls begin_run directly). `decks` is a single deck ref or list;
-- `decorate`, if given, is the current gamemode's ban_pick.decorate_tile (see start_game.lua),
-- reused here so a drafted item's stake/challenge-name context survives onto this screen too.
function SPDRN.show_countdown(on_complete, decks, decorate)
	local opts = {
		label = function(n)
			return (localize('k_starting_in') or 'Starting in') .. ' ' .. n
		end,
	}
	if decks then
		opts.contents = { deck_backs_row(decks, decorate) }
	end
	MPAPI.show_countdown(opts, on_complete)
end
