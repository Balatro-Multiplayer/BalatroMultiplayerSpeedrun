-- RLOG recording for SPDRN: record call sites for shop/hand/blind actions,
-- ported from BalatroMultiplayerPvP's overrides/game.lua + ui/game/functions.lua
-- + ui/game/timer.lua, stripped of everything PvP-specific (opponent HUD sync,
-- timer increments, ready/ante-key handshake -- SPDRN is a solo race, each
-- player only ever needs to record their OWN actions, not synchronize a shared
-- board state). MPAPI.replay.record/card_ref/card_refs (recorder.lua) are
-- already mod-agnostic; only the area/index/permutation helpers needed SPDRN's
-- own copy (SPDRN.RLOG_UTILS, see utils.lua in this same directory).
--
-- UTILS is looked up fresh at each call site below (SPDRN.RLOG_UTILS.foo),
-- not captured into a local at file scope: SPDRN.load_spdrn_dir iterates
-- directory entries in whatever order NFS.getDirectoryItemsInfo returns
-- (not guaranteed alphabetical), so utils.lua is not guaranteed to have run
-- before this file -- a file-scope capture crashed live testing the first
-- time load order happened to put this file first ("attempt to index
-- upvalue 'UTILS' (a nil value)" in CardArea:update). RLOG, by contrast, is
-- safe to capture at file scope: BalatroMultiplayerAPI loads at priority
-- -1000000, fully before SPDRN's own files begin loading at all.
local RLOG = MPAPI.replay

-- PvP overrides the SAME vanilla functions this file does (play/discard/buy/
-- sell/etc, since both mods can independently be installed and both share
-- ordinary Balatro's G.FUNCS names) -- rlog_active() alone only checks
-- "is there ANY active lobby with a code", not which mod's lobby it is, so
-- with both mods installed each one's override would ALSO fire (and
-- double-record) while the OTHER mod's match is live. MPAPI.is_active(mod_id)
-- checks player-engagement ownership (state.engaged_mod == mod_id, see
-- BalatroMultiplayerAPI/api/mod_registry/registry.lua) -- confirmed live via
-- cctl the first time SPDRN's own recording was added alongside PvP: a single
-- play_hand produced two "play" events, one from each mod's wrapper, because
-- neither checked mod ownership before this fix.
local function rlog_active()
	return MPAPI.is_active(SPDRN.id) and RLOG.is_active()
end

-------------------------------------------------------------------------------
-- begin_run: deferred to BLIND_SELECT (see SPDRN._check_pending_rlog_begin
-- below) because `stake` is only known inside each gamemode's own start_run
-- method (objects/gamemodes/*.lua), not at the generic run-transition choke
-- point (ui/lobby/run_start.lua's _check_pending_run_transition) where
-- seed/deck/gamemode are captured. One RLOG run per individual Balatro run
-- (first start AND every restart/seed-change), not one per whole SPDRN match:
-- RLOG's replay mechanism reconstructs exactly one seeded Balatro run, and a
-- SPDRN match can contain several (death -> restart, multi-run formats like
-- White Stake Triple) -- concatenating those into a single non-replayable
-- blob would defeat the point.
-------------------------------------------------------------------------------

SPDRN._rlog_pending_manifest = nil

local check_pending_run_transition_ref = SPDRN._check_pending_run_transition
function SPDRN._check_pending_run_transition()
	local pending = SPDRN._pending_run_transition
	if pending and rlog_active() then
		SPDRN._rlog_pending_manifest = {
			seed = pending.seed,
			deck = tostring(pending.deck),
			gamemode = pending.instance and pending.instance.key,
		}
	end
	check_pending_run_transition_ref()
end

-- Polled from core.lua's Game:update hook, same condition
-- SPDRN._check_pending_dollars_override already waits on (BLIND_SELECT fully
-- set up on the NEW run's G.GAME, not the dying old one).
function SPDRN._check_pending_rlog_begin()
	local pending = SPDRN._rlog_pending_manifest
	if not pending then return end
	if not (G.GAME and G.STATE == G.STATES.BLIND_SELECT and G.blind_select ~= nil) then return end
	SPDRN._rlog_pending_manifest = nil
	RLOG.begin_run({
		seed = pending.seed,
		ruleset = pending.gamemode, -- SPDRN has no separate ruleset concept; gamemode doubles as both
		gamemode = pending.gamemode,
		deck = pending.deck,
		stake = G.GAME.stake,
	})
end

-------------------------------------------------------------------------------
-- Record call sites
-------------------------------------------------------------------------------

local select_blind_ref = G.FUNCS.select_blind
function G.FUNCS.select_blind(e)
	select_blind_ref(e)
	if rlog_active() then
		RLOG.record(
			"select_blind",
			0,
			string.format("action:selectBlind,blind:%s", tostring(e.config.ref_table.key or e.config.ref_table.name))
		)
	end
end

local skip_blind_ref = G.FUNCS.skip_blind
function G.FUNCS.skip_blind(...)
	skip_blind_ref(...)
	if rlog_active() then RLOG.record("skip_blind", 0, "action:skipBlind") end
end

local play_cards_ref = G.FUNCS.play_cards_from_highlighted
function G.FUNCS.play_cards_from_highlighted(...)
	local played = SPDRN.RLOG_UTILS.highlighted_hand_indices()
	local played_refs = RLOG.card_refs(played)
	play_cards_ref(...)
	if #played > 0 and rlog_active() then
		RLOG.record("play", { played, played_refs }, "action:play,cards:" .. table.concat(played, "."))
	end
end

local discard_cards_ref = G.FUNCS.discard_cards_from_highlighted
function G.FUNCS.discard_cards_from_highlighted(e, is_hook_blind)
	local discarded = (not is_hook_blind) and SPDRN.RLOG_UTILS.highlighted_hand_indices() or nil
	local discarded_refs = discarded and RLOG.card_refs(discarded) or nil
	discard_cards_ref(e, is_hook_blind)
	if not is_hook_blind and discarded and #discarded > 0 and rlog_active() then
		RLOG.record("discard", { discarded, discarded_refs }, "action:discard,cards:" .. table.concat(discarded, "."))
	end
end

local sell_card_ref = Card.sell_card
function Card:sell_card()
	if self.ability and self.ability.name and rlog_active() then
		local human = string.format("action:soldCard,card:%s", self.ability.name)
		local area = SPDRN.RLOG_UTILS.area_enum(self.area)
		local idx = SPDRN.RLOG_UTILS.index_in_area(self)
		local ref = RLOG.card_ref(self)
		if area and idx then RLOG.record("sell", { area, idx, ref }, human) end
	end
	return sell_card_ref(self)
end

local cash_out_ref = G.FUNCS.cash_out
function G.FUNCS.cash_out(e)
	if rlog_active() then RLOG.record("cashout", nil, "action:cashOut") end
	return cash_out_ref(e)
end

local reroll_shop_ref = G.FUNCS.reroll_shop
function G.FUNCS.reroll_shop(e)
	if rlog_active() then
		RLOG.record("reroll", nil, string.format("action:rerollShop,cost:%s", G.GAME.current_round.reroll_cost))
	end
	return reroll_shop_ref(e)
end

local buy_from_shop_ref = G.FUNCS.buy_from_shop
function G.FUNCS.buy_from_shop(e)
	local c1 = e.config.ref_table
	if c1 and c1:is(Card) and rlog_active() then
		local human = string.format("action:boughtCardFromShop,card:%s,cost:%s", c1.ability.name, c1.cost)
		local area = SPDRN.RLOG_UTILS.area_enum(c1.area)
		local idx = SPDRN.RLOG_UTILS.index_in_area(c1)
		if area and idx then
			local opcode = "buy"
			local set = c1.ability and c1.ability.set
			if set == "Booster" then
				opcode = "open_pack"
			elseif set == "Voucher" then
				opcode = "voucher"
			end
			local ref = RLOG.card_ref(c1)
			RLOG.record(opcode, { area, idx, ref }, human)
		end
	end
	return buy_from_shop_ref(e)
end

local use_card_ref = G.FUNCS.use_card
function G.FUNCS.use_card(e, mute, nosave)
	local card = e.config and e.config.ref_table
	if card and card.ability and card.ability.name and rlog_active() then
		local human = string.format("action:usedCard,card:%s", card.ability.name)
		if card.area == (G and G.pack_cards) then
			local idx = SPDRN.RLOG_UTILS.index_in_area(card, G.pack_cards)
			if idx then
				local targets = SPDRN.RLOG_UTILS.highlighted_hand_indices()
				local ref = RLOG.card_ref(card)
				local target_refs = RLOG.card_refs(targets)
				RLOG.record("pack_pick", { idx, targets, ref, target_refs }, human)
			end
		else
			local idx = SPDRN.RLOG_UTILS.index_in_area(card)
			if idx then
				local targets = SPDRN.RLOG_UTILS.highlighted_hand_indices()
				local ref = RLOG.card_ref(card)
				local target_refs = RLOG.card_refs(targets)
				RLOG.record("use", { idx, targets, ref, target_refs }, human)
			end
		end
	end
	return use_card_ref(e, mute, nosave)
end

if G.FUNCS.skip_booster then
	local skip_booster_ref = G.FUNCS.skip_booster
	function G.FUNCS.skip_booster(e)
		if rlog_active() then
			local refs = {}
			if G.pack_cards and G.pack_cards.cards then
				for i = 1, #G.pack_cards.cards do
					refs[i] = RLOG.card_ref(G.pack_cards.cards[i])
				end
			end
			RLOG.record("pack_skip", { refs }, "action:skipPack")
		end
		return skip_booster_ref(e)
	end
end

-- Joker/hand/consumable reordering (drag-drop) -- diffed on update since there
-- is no discrete base-game reorder callback, same approach as PvP's
-- CardArea:update override. Debounced until no card in the area is mid-drag.
local function rlog_reorder_area(cardarea)
	if cardarea == G.jokers then return SPDRN.RLOG_UTILS.AREA.jokers end
	if cardarea == G.hand then return SPDRN.RLOG_UTILS.AREA.hand end
	if cardarea == G.consumeables then return SPDRN.RLOG_UTILS.AREA.consumeables end
	return nil
end

local function rlog_area_dragging(cardarea)
	for _, c in ipairs(cardarea.cards) do
		if c.states and c.states.drag and c.states.drag.is then return true end
	end
	return false
end

local cardarea_update_ref = CardArea.update
function CardArea:update(dt)
	cardarea_update_ref(self, dt)

	local area_id = rlog_reorder_area(self)
	if not area_id or not self.cards or #self.cards == 0 then return end
	if not rlog_active() then return end
	if rlog_area_dragging(self) then return end

	local cur = {}
	for i = 1, #self.cards do
		cur[i] = self.cards[i].sort_id
	end
	local prev = self._rlog_order
	self._rlog_order = cur

	if prev and #prev == #cur then
		local perm = SPDRN.RLOG_UTILS.reorder_permutation(prev, self.cards)
		if perm then
			local moved = {}
			for j = 1, #perm do
				if perm[j] ~= j then
					moved[#moved + 1] = { RLOG.card_ref(self.cards[j]), perm[j], j }
				end
			end
			RLOG.record("reorder", { area_id, perm, moved }, "action:reorder,area:" .. area_id)
		end
	end
end
