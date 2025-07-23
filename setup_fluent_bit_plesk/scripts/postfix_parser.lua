function to_kb(bytes)
    return string.format("%.2f", bytes / 1024)
end

-- Parse size=... and return size in bytes
function extract_size(msg)
    local size_str = msg:match("size=(%d+)")
    if size_str then
        return tonumber(size_str)
    end
    return nil
end

function domain_from_email(email)
    if not email then
        return nil
    end
    return email:match("@(.+)")
end

-- Global state
queue_state = queue_state or {}
QUEUE_TTL_SEC = 300 -- Time to live for queued entries (5 minutes)

-- Cleanup function
function cleanup_queue_state(current_ts)
    for qid, state in pairs(queue_state) do
        if state.ts and (current_ts - state.ts > QUEUE_TTL_SEC) then
            queue_state[qid] = nil
        end
    end
end

function timestamp_to_float(ts)
    return ts[1] + ts[2] / 1e9
end

local function detect_mail_stage_from_service(service_string)
    if not service_string then
        return nil
    end

    service_string = service_string:lower()

    if
        service_string:match("local") or service_string:match("pipe") or service_string:match("virtual") or
            service_string:match("lmtp")
     then
        return "final_delivery"
    elseif service_string:match("smtp") then
        return "relay"
    elseif service_string:match("discard") then
        return "discarded"
    elseif service_string:match("bounce") then
        return "bounced"
    else
        return "unknown"
    end
end


function postfix_parse(tag, ts, record)
    local qid = record["queue_id"]
    if not qid then
        return -1, 0, 0
    end

    local msg = record["message"] or ""
    local svc = record["service"] or ""

    local state = queue_state[qid] or {}
    state.ts = ts -- Track timestamp for cleanup

    -- Extract info
    if msg:match("client=") then
        local ch, cip = msg:match("client=([^%[]+)%[([^%]]+)%]")
        state.client_hostname = ch
        state.ip_sender = cip
    end

    if msg:match("from=<") then
        local from = msg:match("from=<([^>]+)>")
        state.sender = from
        state.sender_domain = domain_from_email(from)
    end

    if msg:match("to=<") then
        local to = msg:match("to=<([^>]+)>")
        state.recipient = to
        state.recipient_domain = domain_from_email(to)
    end
    if msg:match("message%-id=<") then
        state.message_id = msg:match("message%-id=<([^>]+)>")
    end

    if msg:match("size=") then
        local size = extract_size(msg)
        if size then
            state.size_b = size
            state.size_kb = to_kb(size)
        end
    end

    local function parse_and_format_delay(value)
        local num = tonumber(value)
        if not num then
            return nil
        end
        if num == 0 then
            return "0"
        end
        return tostring(num):gsub("(%..-)0+$", "%1"):gsub("%.$", "")
    end

    if msg:match("delays=") then
        local q, c, t, d = msg:match("delays=([%d%.]+)/([%d%.]+)/([%d%.]+)/([%d%.]+)")
        if q then
            state.delay_queue_s = parse_and_format_delay(q)
            state.delay_connect_s = parse_and_format_delay(c)
            state.delay_transmit_s = parse_and_format_delay(t)
            state.delay_delivery_s = parse_and_format_delay(d)
            state.total_delay_s =
                parse_and_format_delay(
                state.delay_queue_s + state.delay_connect_s + state.delay_transmit_s + state.delay_delivery_s
            )
        end
    elseif msg:match("delay=") then
        state.total_delay_s = parse_and_format_delay(msg:match("delay=([%d%.]+)"))
    end
    if msg:match("status=") then
        local status = msg:match("status=([%w_]+)")
        state.status = status

        local smtp_code = msg:match("%((%d%d%d)")
        if smtp_code then
            state.smtp_status_code = tonumber(smtp_code)
        end
    end

    if msg:match("dsn=") then
        state.delivery_status_notification = msg:match("dsn=([%d%.]+)")
    end

    state.mail_stage = detect_mail_stage_from_service(svc)
    state.success = false

    if state.smtp_status_code then
        local code = tonumber(state.smtp_status_code)
        if code >= 200 and code < 300 then
            state.success = true
        end
    end

    -- Fallback: use dsn if smtp code is not available
    if not state.success and state.delivery_status_notification then
        local major = tonumber(state.delivery_status_notification:match("^(%d)"))
        if major and major == 2 then
            state.success = true
        end
    end
    -- Emit when status is known
    if state.status then
        state.queue_id = qid
        queue_state[qid] = nil
        cleanup_queue_state(ts)
        return 2, ts, state
    end

    queue_state[qid] = state
    cleanup_queue_state(ts)
    return -1, 0, 0
end