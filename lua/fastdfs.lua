-- 写入文件
local function writefile(filename, info)
    local wfile=io.open(filename, "w") --写入文件(w覆盖)
    assert(wfile)  --打开时验证是否出错
    wfile:write(info)  --写入传入的内容
    wfile:close()  --调用结束后记得关闭
end

-- 检测路径是否目录
local function is_dir(sPath)
    if type(sPath) ~= "string" then return false end

    local response = os.execute( "cd " .. sPath )
    if response == 0 then
        return true
    end
    return false
end

-- 检测文件是否存在
local file_exists = function(name)
    local f=io.open(name,"r")
    if f~=nil then io.close(f) return true else return false end
end

-- 检测table是否包含某个值
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

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
local originalUri = ngx.var.uri; -- /g1/M00/00/33/CgoYvFP0RU2AfE_wAA5UF3DBJeE494.jpg
local originalFile = ngx.var.image_file
local queryString = ngx.var.image_query
local finalFile = nil

thumbnail = gen_thumbnail_param(string.match(queryString, "thumbnail/([0-9]+x[0-9]*)"))
crop = gen_thumbnail_param(string.match(queryString, "crop/([0-9]+x[0-9]*)"))
if not crop then crop = thumbnail end

finalFile = originalFile .. "_" .. thumbnail .. "_" .. crop

--[[
ngx.log(ngx.ERR, originalFile)
ngx.log(ngx.ERR, originalUri)
ngx.log(ngx.ERR, thumbnail)
ngx.log(ngx.ERR, crop)
ngx.log(ngx.ERR, queryString)
ngx.log(ngx.ERR, finalFile)
]]--

-- 如果文件不存在，从tracker下载
if not file_exists(originalFile) then
    local fileid = string.sub(originalUri, 2)
    local fastdfs = require('restyfastdfs')

    local fdfs = fastdfs:new()
    fdfs:set_tracker(ngx.var.tracker_ip, 22122)
    fdfs:set_timeout(1000)
    fdfs:set_tracker_keepalive(0, 100)
    fdfs:set_storage_keepalive(0, 100)
    local data = fdfs:do_download(fileid)
    if data then
        if not is_dir(ngx.var.image_dir) then
            os.execute("mkdir -p " .. ngx.var.image_dir)
        end
        writefile(originalFile, data)
    else
        os.execute("rm " .. originalFile .. "*")
    end
end

if file_exists(originalFile) and not file_exists(finalFile) then
    local thumbnail_sizes = {"240x180", "640x", "640x480", "640x360", "640x320", "700x700", "1000x", "1000x750"}
    local crop_sizes = {"240x180", "640x", "640x480", "700x700", "1000x", "1000x750"}

    -- 如果在允许的缩略图大小中，创建缩略图
    local gm = ngx.var.gm
    if not gm then gm = "gm" end
    if (table.contains(thumbnail_sizes, thumbnail) and table.contains(crop_sizes, crop))  then
        local command = ngx.var.gm .. " convert " .. originalFile  .. " -thumbnail " .. thumbnail .. " -background white -gravity center -extent " .. crop .. " " .. finalFile
        os.execute(command)
    end
end

if file_exists(finalFile) then
    finalUri = string.gsub(originalUri, "/imageView.*", "_" .. thumbnail .. "_" .. crop)
    ngx.exec(finalUri)
    -- ngx.exec("/g1/M00/00/00/CgoYvFQFJRCAQohHAAGDNba3vj4585.jpg")
else
    ngx.exit(404)
end
