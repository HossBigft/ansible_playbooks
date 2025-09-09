local throttle_state = {}

local RATE_LIMIT = 25 -- Max messages per window
local WINDOW_SIZE = 60 -- Time window in seconds
local CHECK_INTERVAL = 5 -- Only update counters every X seconds
local THROTTLE_KEY = "domain"

local last_cleanup = 0
local last_check = 0

function throttle_by_key(tag, timestamp, record)
    local current_time = os.time()
    local key_value = record[THROTTLE_KEY]

    if not key_value then
        return 1, timestamp, record
    end

    if not throttle_state[key_value] then
        throttle_state[key_value] = {
            count = 0,
            window_start = current_time,
            last_seen = current_time
        }
    end

    local state = throttle_state[key_value]

    if current_time - last_check >= CHECK_INTERVAL then
        last_check = current_time
        -- Reset if window expired
        if current_time - state.window_start >= WINDOW_SIZE then
            state.count = 0
            state.window_start = current_time
        end
    end

    state.last_seen = current_time

    if state.count >= RATE_LIMIT then
        return -1, timestamp, record
    end

    state.count = state.count + 1

    if current_time - last_cleanup > CHECK_INTERVAL then
        cleanup_old_entries(current_time)
        last_cleanup = current_time
    end

    return 1, timestamp, record
end

function cleanup_old_entries(current_time)
    local cleanup_age = WINDOW_SIZE * 2
    for key, state in pairs(throttle_state) do
        if current_time - state.last_seen > cleanup_age then
            throttle_state[key] = nil
        end
    end
end
