SPDRN.timer = SPDRN.timer or {}
local timer = SPDRN.timer

-- Begin the on-screen timer from zero. Called from SPDRN.begin_run right after
-- SPDRN._run_started_at is set for a brand-new run.
function timer.start()
	timer._active = true
	timer._frozen = false
	timer._entered_run = false
	timer.text = timer.format(0)
	timer._install_sysclock_hook()
end

-- Resume a timer frozen by the lose screen without resetting the elapsed time, so a
-- restart-after-death keeps counting the same way multi-run progression does (the run
-- clock is never reset between runs of one game).
function timer.resume()
	timer._active = true
	timer._frozen = false
	timer._install_sysclock_hook()
end

-- Freeze the timer at its final value (kept showing on the win/lose screen). The display is
-- torn down by the update loop when the run/lobby ends.
function timer.stop()
	timer._frozen = true
end

function timer._tick()
	if not timer._active then
		return
	end

	-- start() is called from begin_run *before* the stage flips to RUN, so we must not tear
	-- down just because we aren't on the RUN stage yet. Only tear down once we have actually
	-- entered the run and then left it (back to menu, or "Continue in Singleplayer" which
	-- drops the lobby while staying on the RUN stage).
	local in_match = (G.STAGE == G.STAGES.RUN) and MPAPI.is_active(SPDRN.id) and MPAPI.get_current_lobby() and true or false

	if in_match then
		timer._entered_run = true
	elseif timer._entered_run then
		timer._remove_box()
		timer._active = false
		timer._entered_run = false
		return
	else
		return
	end

	if not timer._frozen then
		-- Seed Scout's scouting phase counts down instead of up (see
		-- objects/gamemodes/seed_scout.lua's _seed_scout_remaining_seconds) --
		-- nil for every other gamemode/phase, which falls back to the normal
		-- elapsed-time display below.
		local remaining = SPDRN._seed_scout_remaining_seconds and SPDRN._seed_scout_remaining_seconds()
		if remaining then
			timer.text = timer.format(remaining)
		else
			local started = SPDRN._run_started_at
			local elapsed = started and (love.timer.getTime() - started) or 0
			timer.text = timer.format(elapsed)
		end
	end

	-- A multi-run restart's G:delete_run removes our box but leaves the stale reference; drop it
	-- so the block below rebuilds it (time keeps accumulating -- _run_started_at is not reset).
	if timer._box and timer._box.REMOVED then
		timer._box = nil
	end

	-- If the user's own SystemClock is on screen, the get_formatted_time override already
	-- feeds it our time -- don't draw a second clock. Otherwise draw our own (styled from
	-- their preset when SystemClock is installed, else SPDRN defaults).
	if timer._sysclock() and G.HUD_clock then
		timer._remove_box()
	elseif not timer._box then
		local ok, box = pcall(timer._build_box)
		if ok then
			timer._box = box
		end
	end
end

-- Tick off the frame loop. Mirrors SystemClock's own Game:update wrap; Game exists at load.
if not SPDRN._timer_update_hooked then
	SPDRN._timer_update_hooked = true
	local _timer_update_ref = Game.update
	function Game:update(dt)
		_timer_update_ref(self, dt)
		pcall(timer._tick)
	end
end
