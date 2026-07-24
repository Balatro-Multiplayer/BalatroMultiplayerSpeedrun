-- §16.7: 15 minutes per run a format actually plays (a 3-run format like White
-- Stake Triple gets 3x as long as a 1-run format like Gold Stake Single).
-- Lives in domain/ (loaded before objects/gamemodes/*, see core.lua) since
-- individual gamemode files reference this constant directly in their own
-- duration_cap_seconds field.
SPDRN.DURATION_CAP_PER_RUN_SECONDS = 15 * 60
