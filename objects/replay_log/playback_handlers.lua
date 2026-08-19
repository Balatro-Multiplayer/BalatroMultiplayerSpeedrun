-- SPDRN's opcode semantics for MPAPI's generic playback engine
-- (BalatroMultiplayerAPI/api/playback/{registry,driver,timeline}.lua) --
-- ported from BalatroMultiplayerPvP's lib/playback_handlers.lua, stripped of
-- everything PvP-specific: SPDRN is solo, so every handler is always POV
-- (ctx.is_pov checked defensively, not because a non-POV branch is expected),
-- and there is no opponent-HUD projection, ready/ante-key handshake, or
-- hand_result opcode (SPDRN never records one -- see record.lua's call
-- sites). Every real handler calls the exact real G.FUNCS a live click would
-- call, fed the exact real Card/CardArea objects the recording's positional
-- indices point to -- this works because SPDRN._start_playback
-- (playback_launch.lua) starts a fresh run from the recorded manifest's own
-- seed/deck/stake, and Balatro's RNG is a deterministic hash chain keyed only
-- by seed + call sequence, so the same positional indices point at the same
-- cards again.
--
-- AREA is looked up fresh inside area_object, not captured at file scope --
-- see record.lua's own comment on why (SPDRN.load_spdrn_dir's directory
-- iteration order isn't guaranteed, so utils.lua isn't guaranteed to have
-- run before this file).
local function area_object(area_id)
	local AREA = SPDRN.RLOG_UTILS.AREA
	if area_id == AREA.shop_jokers then return G.shop_jokers end
	if area_id == AREA.shop_booster then return G.shop_booster end
	if area_id == AREA.shop_vouchers then return G.shop_vouchers end
	if area_id == AREA.jokers then return G.jokers end
	if area_id == AREA.consumeables then return G.consumeables end
	if area_id == AREA.hand then return G.hand end
	if area_id == AREA.pack_cards then return G.pack_cards end
	return nil
end

local function highlight_hand_indices(indices)
	for _, i in ipairs(indices or {}) do
		local card = G.hand.cards[i]
		if card then G.hand:add_to_highlighted(card) end
	end
end

MPAPI.playback.register_handler('spdrn', 'manifest', function(_args, _ctx) end)
MPAPI.playback.register_handler('spdrn', 'end', function(_args, _ctx) end)
MPAPI.playback.register_handler('spdrn', 'chk', function(_args, _ctx) end)
-- Pure bookkeeping (see record.lua's ease_dollars hook) -- the real dollar
-- change already happens as a side effect of whatever action caused it
-- (buy/sell/etc, each already replayed by its own handler), nothing to apply.
MPAPI.playback.register_handler('spdrn', 'money_delta', function(_args, _ctx) end)

-- Same real-UIBox technique PvP's equivalent handler needed (confirmed live
-- there, a crash risk from calling select_blind before G.blind_select's own
-- (re)built UIBox exists on this frame) -- deferred via
-- SPDRN._playback_wait_for the same way SPDRN._start_playback reaches
-- BLIND_SELECT in the first place.
local function do_select_blind()
	local blind_key = G.GAME.round_resets.blind_choices[G.GAME.blind_on_deck]
	G.FUNCS.select_blind({ config = { ref_table = G.P_BLINDS[blind_key] }, UIBox = G.blind_select })
end

MPAPI.playback.register_handler('spdrn', 'select_blind', function(_args, ctx)
	if not ctx.is_pov then return end
	SPDRN._playback_wait_for(function()
		return G.STATE == G.STATES.BLIND_SELECT and G.blind_select ~= nil and G.blind_select.alignment.offset.x == 0
	end, do_select_blind)
end)

MPAPI.playback.register_handler('spdrn', 'skip_blind', function(_args, ctx)
	if not ctx.is_pov then return end
	SPDRN._playback_wait_for(function()
		return G.STATE == G.STATES.BLIND_SELECT and G.blind_select ~= nil and G.blind_select.alignment.offset.x == 0
	end, function()
		G.FUNCS.skip_blind({ UIBox = G.blind_select })
	end)
end)

MPAPI.playback.register_handler('spdrn', 'play', function(args, ctx)
	if not ctx.is_pov then return end
	local indices = args and args[1]
	if not indices then return end
	highlight_hand_indices(indices)
	G.FUNCS.play_cards_from_highlighted()
end)

MPAPI.playback.register_handler('spdrn', 'discard', function(args, ctx)
	if not ctx.is_pov then return end
	local indices = args and args[1]
	if not indices then return end
	highlight_hand_indices(indices)
	G.FUNCS.discard_cards_from_highlighted(nil, false)
end)

MPAPI.playback.register_handler('spdrn', 'sell', function(args, ctx)
	if not ctx.is_pov then return end
	local area_id, idx = args and args[1], args and args[2]
	local area = area_object(area_id)
	local card = area and area.cards and area.cards[idx]
	if card then
		card:sell_card()
		SMODS.calculate_context({ selling_card = true, card = card })
	end
end)

local function replay_buy(args, ctx)
	if not ctx.is_pov then return end
	local area_id, idx = args and args[1], args and args[2]
	local area = area_object(area_id)
	local card = area and area.cards and area.cards[idx]
	if card then
		G.FUNCS.buy_from_shop({ config = { ref_table = card } })
	end
end
MPAPI.playback.register_handler('spdrn', 'buy', replay_buy)
MPAPI.playback.register_handler('spdrn', 'open_pack', replay_buy)
MPAPI.playback.register_handler('spdrn', 'voucher', replay_buy)

MPAPI.playback.register_handler('spdrn', 'use', function(args, ctx)
	if not ctx.is_pov then return end
	local idx, targets = args and args[1], args and args[2]
	local card = G.consumeables and G.consumeables.cards and G.consumeables.cards[idx]
	if not card then return end
	if targets then highlight_hand_indices(targets) end
	G.FUNCS.use_card({ config = { ref_table = card } })
end)

MPAPI.playback.register_handler('spdrn', 'pack_pick', function(args, ctx)
	if not ctx.is_pov then return end
	local idx, targets = args and args[1], args and args[2]
	local card = G.pack_cards and G.pack_cards.cards and G.pack_cards.cards[idx]
	if not card then return end
	if targets then highlight_hand_indices(targets) end
	G.FUNCS.use_card({ config = { ref_table = card } })
end)

MPAPI.playback.register_handler('spdrn', 'pack_skip', function(_args, ctx)
	if ctx.is_pov then G.FUNCS.skip_booster({ config = {} }) end
end)

MPAPI.playback.register_handler('spdrn', 'reroll', function(_args, ctx)
	if ctx.is_pov then G.FUNCS.reroll_shop({ config = {} }) end
end)

-- reorder's perm is "new-position -> old-index" (SPDRN.RLOG_UTILS.reorder_permutation):
-- new_cards[j] = old_cards[perm[j]]. Same direct-splice technique as PvP's
-- equivalent handler (mirrors vanilla's own sort-button pattern).
MPAPI.playback.register_handler('spdrn', 'reorder', function(args, ctx)
	if not ctx.is_pov then return end
	local area_id, perm = args and args[1], args and args[2]
	local area = area_object(area_id)
	if not (area and perm) then return end
	local old_cards = area.cards
	local new_cards = {}
	for j = 1, #perm do
		new_cards[j] = old_cards[perm[j]]
	end
	area.cards = new_cards
	if area.set_ranks then area:set_ranks() end
end)

MPAPI.playback.register_handler('spdrn', 'cashout', function(_args, ctx)
	if ctx.is_pov then G.FUNCS.cash_out({ config = {} }) end
end)
