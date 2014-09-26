local tracker = require('resty.fastdfs.tracker')
local storage = require('resty.fastdfs.storage')


module(...)

function _dump_res(res)
    for i in pairs(res) do
        ngx.say(string.format("%s:%s",i, res[i]))
        ngx.log(ngx.ERR, string.format("%s:%s",i, res[i]))
    end
    ngx.say("")
end

local fileid = "g1/M00/00/00/CgoYr1QIOgSAF6vPAAENdjraJ243824185"

local tk = tracker:new()
tk:set_timeout(3000)
local ok, err = tk:connect({host='192.168.110.218', port=22122})


if not ok then
    ngx.say('connect error:' .. err)
    ngx.exit(200)
end

local res, err = tk:query_storage_store()
if not res then
    ngx.say("query storage error:" .. err)
    ngx.exit(200)
end



local res, err = tk:query_storage_fetch1(fileid)
if not res then
    ngx.say("query storage error:" .. err)
    ngx.exit(200)
else
    _dump_res(res)
    ngx.exit(200)
end
