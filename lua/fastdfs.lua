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

-- 查找是否有图片大小的后缀
local area = nil
local originalUri = ngx.var.uri;
local originalFile = ngx.var.file;
local index = string.find(ngx.var.uri, "([0-9]+)x([0-9]+)");
if index then
    originalUri = string.sub(ngx.var.uri, 0, index-2);
    area = string.sub(ngx.var.uri, index);
    index = string.find(area, "([.])");
    area = string.sub(area, 0, index-1);

    local index = string.find(originalFile, "([0-9]+)x([0-9]+)");
    originalFile = string.sub(originalFile, 0, index-2)
end

-- 如果文件不存在，从tracker下载
if not file_exists(originalFile) then
    local fileid = string.sub(originalUri, 2);
    local fastdfs = require('restyfastdfs')

    local fdfs = fastdfs:new()
    fdfs:set_tracker("192.168.110.218", 22122)
    fdfs:set_timeout(1000)
    fdfs:set_tracker_keepalive(0, 100)
    fdfs:set_storage_keepalive(0, 100)
    local data = fdfs:do_download(fileid)
    if data then
        if not is_dir(ngx.var.image_dir) then
            os.execute("mkdir -p " .. ngx.var.image_dir)
        end
        writefile(originalFile, data)
    end
end

local image_sizes = {"240x180", "640x0", "640x480", "700x700", "1000x0", "1000x750"};
-- local image_sizes = {"80x80", "800x600", "40x40", "60x60"};
function table.contains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end

-- 如果在允许的缩略图大小中，创建缩略图
-- 如果有了是否还会再转呢？？
if table.contains(image_sizes, area) then
    local command = "/opt/apps/GraphicsMagick/bin/gm convert " .. originalFile  .. " -thumbnail " .. area .. " -background white -gravity center -extent " .. area .. " " .. ngx.var.file;
    os.execute(command);
end;

if file_exists(ngx.var.file) then
    --ngx.req.set_uri(ngx.var.uri, true);
    ngx.exec(ngx.var.uri)
else
    ngx.exit(404)
end

