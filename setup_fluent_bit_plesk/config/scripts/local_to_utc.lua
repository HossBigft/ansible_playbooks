
local function get_system_tz_offset_hours()
    local tz = os.date("%z") -- returns "+0500" or "-0700"
    if not tz then
        return 0
    end
    return tonumber(tz:sub(1, 3)) or 0
end

local tz_offset_hours = get_system_tz_offset_hours()

function adjust_to_utc(tag, timestamp, record)
    local ts_str = record["time"]
    if not ts_str then
        return 1, timestamp, record
    end

    local month_map = {
        Jan = 1,
        Feb = 2,
        Mar = 3,
        Apr = 4,
        May = 5,
        Jun = 6,
        Jul = 7,
        Aug = 8,
        Sep = 9,
        Oct = 10,
        Nov = 11,
        Dec = 12
    }
    local mon, day, hour, min, sec = ts_str:match("(%w+)%s+(%d+)%s+(%d+):(%d+):(%d+)")
    if not mon then
        return 1, timestamp, record
    end

    local ts_table = {
        year = os.date("%Y"),
        month = month_map[mon],
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    }

    -- Your server clock is UTC-based, no offset needed
    local utc_ts = os.time(ts_table)

    record["@timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ", utc_ts)
    return 1, timestamp, record
end
