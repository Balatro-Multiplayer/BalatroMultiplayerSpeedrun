-- Card/CardArea introspection needed to record RLOG events, ported from
-- BalatroMultiplayerPvP/lib/card_utils.lua (PVP.UTILS.area_enum/index_in_area/
-- highlighted_hand_indices/reorder_permutation). Those four are pure engine
-- introspection with no PvP-specific logic -- MPAPI.replay.card_ref/card_refs
-- (BalatroMultiplayerAPI/api/replay/recorder.lua) already cover card identity
-- generically, but the area/index/permutation helpers a mod needs to build the
-- positional args those calls take were never lifted out of PVP.UTILS, so
-- SPDRN gets its own copy rather than reaching into another mod's namespace.
SPDRN.RLOG_UTILS = SPDRN.RLOG_UTILS or {}
local UTILS = SPDRN.RLOG_UTILS

-- Stable area enum for the carbon replay stream -- same values as
-- PVP.UTILS.AREA so a future shared reader doesn't need a second legend.
UTILS.AREA = {
	shop_jokers = 1,
	shop_booster = 2,
	shop_vouchers = 3,
	jokers = 4,
	consumeables = 5,
	hand = 6,
	pack_cards = 7,
}

function UTILS.area_enum(area)
	if not area or not G then
		return nil
	end
	if area == G.shop_jokers then
		return UTILS.AREA.shop_jokers
	end
	if area == G.shop_booster then
		return UTILS.AREA.shop_booster
	end
	if area == G.shop_vouchers then
		return UTILS.AREA.shop_vouchers
	end
	if area == G.jokers then
		return UTILS.AREA.jokers
	end
	if area == G.consumeables then
		return UTILS.AREA.consumeables
	end
	if area == G.hand then
		return UTILS.AREA.hand
	end
	if area == G.pack_cards then
		return UTILS.AREA.pack_cards
	end
	return nil
end

function UTILS.index_in_area(card, area)
	area = area or (card and card.area)
	if not card or not area or not area.cards then
		return nil
	end
	for i = 1, #area.cards do
		if area.cards[i] == card then
			return i
		end
	end
	return nil
end

function UTILS.highlighted_hand_indices()
	local out = {}
	if not (G and G.hand and G.hand.highlighted) then
		return out
	end
	for _, c in ipairs(G.hand.highlighted) do
		local i = UTILS.index_in_area(c, G.hand)
		if i then
			out[#out + 1] = i
		end
	end
	table.sort(out)
	return out
end

function UTILS.reorder_permutation(old_ids, cards)
	if not old_ids or not cards or #cards == 0 or #old_ids ~= #cards then
		return nil
	end
	local pos = {}
	for i = 1, #old_ids do
		pos[old_ids[i]] = i
	end
	local perm = {}
	local changed = false
	for j = 1, #cards do
		local oi = pos[cards[j].sort_id]
		if not oi then
			return nil
		end
		perm[j] = oi
		if oi ~= j then
			changed = true
		end
	end
	if not changed then
		return nil
	end
	return perm
end
