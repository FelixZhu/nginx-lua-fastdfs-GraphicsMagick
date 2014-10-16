local tools = require('utils.tools')

local function gen_thumbnail_uri(uri, thumbnail, crop)
    return string.gsub(uri, "/imageView.*", "_" .. thumbnail .. "_" .. crop)
end

local function gen_thumbnail_param(s)
    if not s then
        return s
    else
        return string.gsub(s, "x0", "x")
    end
end

-------------------------------------
-- 执行代码开始
-------------------------------------

-- 查找是否有图片大小的后缀
local thumbnail = nil
local crop = nil
local query = nil
-- 从ngx.var获取参数的时候最好赋值到本地变量，否则会重复分配内存，在请求结束的时候才会释放
local original_uri = ngx.var.uri; -- /g1/M00/00/33/CgoYvFP0RU2AfE_wAA5UF3DBJeE494.jpg
local original_file = ngx.var.image_file
local query_string = ngx.var.image_query
local final_file = nil

thumbnail = gen_thumbnail_param(string.match(query_string, "thumbnail/([0-9]+x[0-9]*)"))
crop = gen_thumbnail_param(string.match(query_string, "crop/([0-9]+x[0-9]*)"))
if not crop then crop = thumbnail end

final_file = original_file .. "_" .. thumbnail .. "_" .. crop

--[[
ngx.log(ngx.ERR, original_file)
ngx.log(ngx.ERR, original_uri)
ngx.log(ngx.ERR, thumbnail)
ngx.log(ngx.ERR, crop)
ngx.log(ngx.ERR, query_string)
ngx.log(ngx.ERR, final_file)
--]]--


-- 如果文件不存在，从tracker下载
if not tools.file_exists(original_file) then
    local tracker = require('resty.fastdfs.tracker')
    local storage = require('resty.fastdfs.storage')

    local fileid = string.match(original_uri, "/(.*)/imageView.*")

    local tk = tracker:new()
    tk:set_timeout(3000)
    local ok, err = tk:connect({host=ngx.var.tracker_ip, port=22122})
    if not ok then
        ngx.log(ngx.ERR, "connect tracker error")
        ngx.exit(200)
    end

    local res, err = tk:query_storage_fetch1(fileid)
    if not res then
        ngx.log(ngx.ERR, "query storage error, fileid:" .. fileid)
        ngx.exit(200)
    end

    --[[
    ngx.log(ngx.ERR, fileid)
    ngx.log(ngx.ERR, res['host'])
    --]]--
    if tools.file_exists(original_file .. '_240x180_240x180') then
        os.execute("rm " .. original_file .. "_*")
        ngx.exit(404)
    else
        -- ngx.redirect("http://" .. res['host'] .. "/" .. fileid .. "/imageView/v1" .. query_string)
        ngx.redirect("http://" .. res['host'] .. "/" .. fileid)
    end
end

if (tools.file_exists(original_file) and
    not tools.file_exists(final_file)) then
    local thumbnail_sizes = {
        "240x180", "640x", "640x480",
        "640x360", "640x320", "700x700",
        "1000x", "1000x750",
    }
    local crop_sizes = {
        "240x180", "640x", "640x480",
        "700x700", "1000x", "1000x750"
    }

    -- 如果在允许的缩略图大小中，创建缩略图
    local gm = ngx.var.gm
    if not gm then gm = "gm" end
    if (tools.table_contains(thumbnail_sizes, thumbnail) and
        tools.table_contains(crop_sizes, crop))  then
        local command_list = {
            ngx.var.gm, "convert", original_file, "-thumbnail",
            thumbnail.."^", "-background white -gravity center -crop",
            crop, final_file
        }
        local command = table.concat(command_list, " ")
        os.execute(command)
    end
end

if tools.file_exists(final_file) then
    -- 拼凑最终URL并内部跳转
    final_uri = string.gsub(original_uri, "/imageView.*",
        "_" .. thumbnail .. "_" .. crop)
    ngx.exec(final_uri)
else
    ngx.exit(404)
end
