function add_domain(tag, timestamp, record)
    local log_path = record["log_path"]
    if log_path then
        local domain = string.match(log_path, "/var/www/vhosts/system/([^/]+)/logs/")
        if domain then
            record["domain"] = domain
        end
    end
    return 1, timestamp, record
end