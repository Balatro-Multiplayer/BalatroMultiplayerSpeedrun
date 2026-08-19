-- SPDRN-only mid-match run-transition MPAPI.RLOG_CODEs, replacing the three
-- old per-run `MPAPI.replay.end_run({result=...})` calls (objects/matchmaking/
-- progress.lua's record_run_completed, ui/lose_screen.lua's _check_run_lost)
-- now that begin_run/end_run fire once per MATCH (see ui/lobby/run_start.lua's
-- SPDRN.begin_run and objects/matchmaking/result.lua/objects/actions/forfeit.lua's
-- retimed end_run calls) rather than once per individual Balatro run.
--
-- run_complete's replay is a no-op: for genuinely multi-run formats (Stake
-- Climb, White Stake Triple), the transition to the NEXT run already happens
-- automatically and correctly during replay -- SPDRN.request_run_transition
-- is called from inside a real gamemode's own `calculate()` context handler
-- (see objects/gamemodes/stake_climb.lua), which fires as a genuine side
-- effect of replaying real gameplay actions through the real engine, exactly
-- as it would live. Explicitly restarting here too would race/duplicate that
-- already-in-flight transition. For single-run/terminal formats
-- (Gold Stake Single, etc), record_run_completed fires once with nothing
-- further to transition to at all -- either way, nothing for replay to do.
--
-- run_died/run_restarted DO need explicit handling: unlike run_complete,
-- both correspond to a UI button click with no natural replay-time trigger
-- (the lose screen's "Restart Run" button, or Seed Scout's own silent
-- on_run_lost auto-restart) -- there is no recorded opcode for "clicked
-- Restart", so replay has to programmatically reproduce what that click
-- would have done via SPDRN._playback_handle_run_transition
-- (playback_launch.lua).
--
-- Known v1 gap: if the ORIGINAL player forfeited (rather than restarting)
-- after a run_died, replay still eagerly restarts the run -- the recording's
-- following 'end'/'chk' still correctly finishes the driver, just leaving an
-- extra unplayed restarted run on screen instead of the forfeit screen.
-- There is no recorded signal distinguishing "about to restart" from "about
-- to forfeit" at the moment run_died dispatches. Not solved this pass, same
-- spirit as playback_launch.lua's own documented "Known v1 gap" comment.
local function noop_replay(self, _args, ctx)
	if ctx.schema_version >= 1 then
		-- no-op; see file header
	end
end

MPAPI.RLOG_CODE {
	key = 'run_complete',
	mods = { 'spdrn' },
	write = function(self)
		self:record(nil, "action:runComplete")
	end,
	replay = noop_replay,
}

MPAPI.RLOG_CODE {
	key = 'run_died',
	mods = { 'spdrn' },
	write = function(self)
		self:record(nil, "action:runDied")
	end,
	replay = function(self, _args, ctx)
		if ctx.schema_version >= 1 then
			if ctx.is_pov then SPDRN._playback_handle_run_transition(self.key, ctx) end
		end
	end,
}

MPAPI.RLOG_CODE {
	key = 'run_restarted',
	mods = { 'spdrn' },
	write = function(self)
		self:record(nil, "action:runRestarted")
	end,
	replay = function(self, _args, ctx)
		if ctx.schema_version >= 1 then
			if ctx.is_pov then SPDRN._playback_handle_run_transition(self.key, ctx) end
		end
	end,
}
