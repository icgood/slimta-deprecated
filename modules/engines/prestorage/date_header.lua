
slimta.config.new("config.modules.engines.prestorage.date_header.build_date", nil)

-- {{{ add_date_header()
local function add_date_header(msg)
    if not msg.headers.date then
        local date = config.modules.engines.prestorage.date_header.build_date()
        if not date then
            date = os.date("%a, %d %b %Y %T %z")
        end

        msg:add_header("Date", date)
    end
end
-- }}}

table.insert(modules.engines.prestorage, add_date_header)

-- vim:foldmethod=marker:sw=4:ts=4:sts=4:et:
