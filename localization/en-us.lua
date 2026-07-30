return {
	misc = {
		dictionary = {
			-- Speedrun-specific strings only. Shared menu / matchmaking strings
			-- (b_leaderboard_cap, b_practice_cap, b_cancel_search_cap, b_ready_cap,
			-- b_unready_cap, k_ranked_cap, k_casual_cap, k_rating_cap,
			-- k_waiting_for_players, ...) now live in MultiplayerAPI's localization so
			-- every consumer mod shares them instead of duplicating.
			b_play_again_cap = 'Play Again',
			k_best_time_cap = 'BEST TIME',
			k_placement_games_cap = 'PLACEMENT',
			k_get_ready = 'Get ready!',
			k_starting_in = 'Starting in',
			k_seed_vote = 'Vote to change seed',
			k_times_up = "Time's Up",
			k_duration_cap_cap = 'Duration Cap',
			-- Title for the run-lost-to-a-blind screen (SPDRN.show_run_lost_screen), in place
			-- of the base game's own 'ph_game_over' -- same DynaText styling (MPAPI.end_screen_uibox
			-- title_key), just SPDRN's own wording since that screen is a restartable mid-run
			-- setback, not the terminal loss the base "GAME OVER" text implies.
			ph_oops = 'OOPS!',
		},
	},
}
