dofile("table_show.lua")
dofile("urlcode.lua")
JSON = (loadfile "JSON.lua")()
local urlparse = require("socket.url")
local http = require("socket.http")

local item_value = os.getenv('item_value')
local item_type = os.getenv('item_type')
local item_dir = os.getenv('item_dir')
local warc_file_base = os.getenv('warc_file_base')

local url_count = 0
local tries = 0
local downloaded = {}
local addedtolist = {}
local abortgrab = false

local discovered = {}

for ignore in io.open("ignore-list", "r"):lines() do
  io.stdout:write("lua-socket not corrently installed.\n")
  io.stdout:flush()
  downloaded[ignore] = true
end

if urlparse == nil or http == nil then
  abortgrab = true
end

read_file = function(file)
  if file then
    local f = assert(io.open(file))
    local data = f:read("*all")
    f:close()
    return data
  else
    return ""
  end
end

allowed = function(url, parenturl)
  if string.match(url, "'+")
    or string.match(url, "[<>\\%*%$%^%[%]%(%){}]") then
    return false
  end

  local tested = {}
  for s in string.gmatch(url, "([^/]+)") do
    if tested[s] == nil then
      tested[s] = 0
    end
    if tested[s] == 6 then
      return false
    end
    tested[s] = tested[s] + 1
  end

--[[  if string.match(url, "%?startTime=[0-9]+%-[0-9]+%-[0-9]+T[0-9]+:[0-9]+:[0-9]+&endTime=[0-9]+%-[0-9]+%-[0-9]+T[0-9]+:[0-9]+:[0-9]+$") then
    local start_time, end_time = string.match(url, "%?startTime=([0-9%-T:]+)&endTime=([0-9%-T:]+)$")
    start_time = string.gsub(start_time, "[%-T:]", "")
    end_time = string.gsub(end_time, "[%-T:]", "")
    discovered["posts:" .. item_value .. ":" .. start_time .. ":" .. end_time] = true
  end

  if parenturl ~= nil and string.match(parenturl, "%?startTime=[0-9%-T:]+&endTime=[0-9%-T:]+$") then
    downloaded[url] = true
    return false
  end]]

  local match = string.match(url, "^https?://([^%.]+%.kinja%.com)/")
  if match and match ~= item_value then
    discovered[match] = true
  end

  if parenturl and string.match(parenturl, "/ajax/comments/")
    and string.match(url, "^https?://[^/]+/[0-9]+$") then
    return false
  end

  if string.match(url, "^https?://([^/]+)") == item_value
    or string.match(url, "^https?://[^/]*kinja%-img%.com/")
    or string.match(url, "^https?://[^/]*akamaihd%.net/") then
    return true
  end

  return false
end

wget.callbacks.download_child_p = function(urlpos, parent, depth, start_url_parsed, iri, verdict, reason)
  local url = urlpos["url"]["url"]
  local html = urlpos["link_expect_html"]

  if (downloaded[url] ~= true and addedtolist[url] ~= true)
    and not (string.match(url, "^https?://[^/]*kinja%-img%.com/") and downloaded[string.lower(url)])
    and not (string.match(url, "/$") and downloaded[string.match(url, "^(.+)/$")])
    and (allowed(url, parent["url"]) or html == 0) then
    addedtolist[url] = true
if string.match(url, "akamaihd") then print(url) end
    return true
  end

  return false
end

wget.callbacks.get_urls = function(file, url, is_css, iri)
  local urls = {}
  local html = nil

  downloaded[url] = true

  local function check(urla)
    local origurl = url
    local url = string.match(urla, "^([^#]+)")
    local url_ = string.gsub(string.match(url, "^(.-)%.?$"), "&amp;", "&")
    if (downloaded[url_] ~= true and addedtolist[url_] ~= true)
      and allowed(url_, origurl) then
if string.match(url_, "akamaihd") then print(url_) end
      table.insert(urls, { url=url_ })
      addedtolist[url_] = true
      addedtolist[url] = true
    end
  end

  local function checknewurl(newurl)
    if string.match(newurl, "%s") then
      for s in string.gmatch(url, "([^%s]+)") do
        check(s)
      end
    elseif string.match(newurl, "^https?:////") then
      check(string.gsub(newurl, ":////", "://"))
    elseif string.match(newurl, "^https?://") then
      check(newurl)
    elseif string.match(newurl, "^https?:\\/\\?/") then
      check(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^\\/") then
      checknewurl(string.gsub(newurl, "\\", ""))
    elseif string.match(newurl, "^//") then
      check(urlparse.absolute(url, newurl))
    elseif string.match(newurl, "^/") then
      check(urlparse.absolute(url, newurl))
    elseif string.match(newurl, "^%.%./") then
      if string.match(url, "^https?://[^/]+/[^/]+/") then
        check(urlparse.absolute(url, newurl))
      else
        checknewurl(string.match(newurl, "^%.%.(/.+)$"))
      end
    elseif string.match(newurl, "^%./") then
      check(urlparse.absolute(url, newurl))
    end
  end

  local function checknewshorturl(newurl)
    if string.match(newurl, "^%?") then
      check(urlparse.absolute(url, newurl))
    elseif not (string.match(newurl, "^https?:\\?/\\?//?/?")
        or string.match(newurl, "^[/\\]")
        or string.match(newurl, "^%./")
        or string.match(newurl, "^[jJ]ava[sS]cript:")
        or string.match(newurl, "^[mM]ail[tT]o:")
        or string.match(newurl, "^vine:")
        or string.match(newurl, "^android%-app:")
        or string.match(newurl, "^ios%-app:")
        or string.match(newurl, "^%${")) then
      check(urlparse.absolute(url, newurl))
    end
  end

  if allowed(url, nil) and status_code == 200
    and not string.match(url, "^https?://[^/]*kinja%-img%.com")
    and not string.match(url, "^https?://[^/]*akamaihd%.net/.+%.ts$")
    and not string.match(url, "^https?://[^/]+/x%-kinja%-static/") then
    html = read_file(file)
    if string.match(url, "^https?://[^/]*akamaihd%.net/.+%.m3u8$") then
      for newurl in string.gmatch(html, "([^\n]+)") do
        if not string.match(newurl, "^#") then
          check(urlparse.absolute(url, newurl))
        end
      end
    end
    local match = string.match(url, "/embed/comments/magma/([0-9]+)")
    if match then
      local ownerid = string.match(string.gsub(html, "\\x22", '"'), '"ownerId":"([0-9]+)"')
      if not ownerid then
        io.stdout:write("ownerId could not be found.\n")
        io.stdout:flush()
        abortgrab = true
      end
      checknewurl("/ajax/comments/views/curatedReplies/" .. match .. "?maxReturned=5&cache=true&sorting=top&userIds=1148658")
      checknewurl("/ajax/comments/views/replies/" .. match .. "?startIndex=0&maxReturned=5&maxChildren=4&approvedOnly=true&cache=true&experimental=true&sorting=top")
    end
    if string.match(url, "/ajax/comments/views/replies/[0-9]+") then
      local data = JSON:decode(html)
      if not data then
        io.stdout:write("Expected JSON data.\n")
        io.stdout:flush()
        abortgrab = true
      end
      nextpage = data["data"]
      if nextpage then
        local items = nextpage["items"]
        if items then
          for _, item in pairs(items) do
            if item["children"]
              and item["children"]["pagination"]
              and item["children"]["pagination"]["next"] then
              local postid = item["reply"]["id"]
              local next_ = item["children"]["pagination"]["next"]
              local start = "/ajax/comments/views/flatReplies/" .. tostring(postid) .. "?startIndex=" .. tostring(next_["startIndex"])
              checknewurl(start .. "&maxReturned=100&approvedOnly=true&cache=true&sorting=top")
              checknewurl(start .. "&maxReturned=" .. tostring(next_["maxReturned"]) .. "&approvedOnly=true&cache=true&sorting=top")
            end
          end
        end
      end
      if nextpage["pagination"]
        and nextpage["pagination"]["next"] then
        nextpage = nextpage["pagination"]["next"]
        newurl = string.gsub(url, "([%?&]startIndex=)[0-9]+", "%1" .. tostring(nextpage["startIndex"]))
        newurl = string.gsub(newurl, "([%?&]maxReturned=)[0-9]+", "%1" .. tostring(nextpage["maxReturned"]))
        check(newurl)
      end
    end
    for newurl in string.gmatch(string.gsub(html, "&quot;", '"'), '([^"]+)') do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(string.gsub(html, "&#039;", "'"), "([^']+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, ">%s*([^<%s]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "%[%s*([^%[%]%s]+)") do
      checknewurl(newurl)
    end
    for newurl in string.gmatch(html, "href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, "[^%-]href='([^']+)'") do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, '[^%-]href="([^"]+)"') do
      checknewshorturl(newurl)
    end
    for newurl in string.gmatch(html, ":%s*url%(([^%)]+)%)") do
      checknewurl(newurl)
    end
  end

  return urls
end

wget.callbacks.httploop_result = function(url, err, http_stat)
  status_code = http_stat["statcode"]

  url_count = url_count + 1
  io.stdout:write(url_count .. "=" .. status_code .. " " .. url["url"] .. "  \n")
  io.stdout:flush()

  if status_code >= 300 and status_code <= 399 then
    local newloc = urlparse.absolute(url["url"], http_stat["newloc"])
    if url_count == 1 then
      local site = string.match(newloc, "^https?://([^/]+)")
      if site ~= item_value then
        discovered[site] = true
      end
    end
    if downloaded[newloc] == true or addedtolist[newloc] == true
      or not allowed(newloc, url["url"]) then
      tries = 0
      return wget.actions.EXIT
    end
  end

  if status_code >= 200 and status_code <= 399 then
    downloaded[url["url"]] = true
    downloaded[string.gsub(url["url"], "https?://", "http://")] = true
  end

  if abortgrab == true then
    io.stdout:write("ABORTING...\n")
    io.stdout:flush()
    return wget.actions.ABORT
  end

  if (status_code >= 401 and status_code ~= 404)
    or status_code > 500
    or status_code == 0 then
    io.stdout:write("Server returned "..http_stat.statcode.." ("..err.."). Sleeping.\n")
    io.stdout:flush()
    local maxtries = 10
    if not allowed(url["url"], nil) then
      maxtries = 3
    end
    if tries >= maxtries then
      io.stdout:write("\nI give up...\n")
      io.stdout:flush()
      tries = 0
      if maxtries == 3 then
        return wget.actions.EXIT
      else
        return wget.actions.ABORT
      end
    else
      os.execute("sleep " .. math.floor(math.pow(2, tries)))
      tries = tries + 1
      return wget.actions.CONTINUE
    end
  end

  tries = 0

  local sleep_time = 0

  if sleep_time > 0.001 then
    os.execute("sleep " .. sleep_time)
  end

  return wget.actions.NOTHING
end

wget.callbacks.finish = function(start_time, end_time, wall_time, numurls, total_downloaded_bytes, total_download_time)
  local new_items = nil
  for site, _ in pairs(discovered) do
    if new_items == nil then
      new_items = "site:" .. site
    else
      new_items = new_items .. "\0site:" .. site
    end
  end

  if new_items ~= nil then
    local tries = 0
    while tries < 10 do
      local body, code, headers, status = http.request(
        "http://blackbird-amqp.meo.ws:23038/kinja-e0vkal5szhf5paz/",
        new_items
      )
      if code == 200 or code == 409 then
        break
      end
      os.execute("sleep " .. tostring(math.floor(math.pow(2, tries))))
      tries = tries + 1
    end
    if tries == 10 then
      io.stdout:write("Could not report discovered items.\n")
      io.stdout:flush()
      abortgrab = true
    end
  end
end

wget.callbacks.before_exit = function(exit_status, exit_status_string)
  if abortgrab == true then
    return wget.exits.IO_FAIL
  end
  return exit_status
end

