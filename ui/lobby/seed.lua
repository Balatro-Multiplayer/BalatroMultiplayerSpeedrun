local SEED_CHARS = 'ABCDEFGHIJKLMNPQRSTUVWXYZ123456789'

SPDRN.generate_seed = function()
	local seed = ''
	for i = 1, 8 do
		local idx = math.random(1, #SEED_CHARS)
		seed = seed .. SEED_CHARS:sub(idx, idx)
	end
	return seed
end

-- Deterministically derive run N's seed from the match's base (run-1) seed. Every client
-- shares the broadcast base seed, so they all compute identical seeds for the later runs of a
-- multi-run format without an extra broadcast. The per-character djb2 hash is kept under 2^24
-- so `h * 33` never loses precision in LuaJIT's double arithmetic (keeping it cross-client
-- deterministic); this is a spread function for seed strings, not a security hash.
--
-- Each position is salted with a distinct large constant rather than the bare loop index 1..8:
-- djb2 is affine in a single trailing byte, so salting with the raw index made consecutive
-- positions hash to consecutive SEED_CHARS indices (e.g. "EFGHIJKL"). Salting with values that
-- differ across multiple digits breaks that linearity.
local POSITION_SALTS = {
	2654435761, 2246822519, 3266489917, 668265263,
	374761393, 2654435769, 2870177450, 3266489927,
}

SPDRN.derive_seed = function(base_seed, run_idx)
	local seed = ''
	for i = 1, 8 do
		local material = tostring(base_seed) .. ':' .. tostring(run_idx) .. ':' .. tostring(POSITION_SALTS[i])
		local h = 5381
		for j = 1, #material do
			h = (h * 33 + material:byte(j)) % 16777216
		end
		local idx = (h % #SEED_CHARS) + 1
		seed = seed .. SEED_CHARS:sub(idx, idx)
	end
	return seed
end
