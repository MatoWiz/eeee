local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ServerStorage = game:GetService("ServerStorage")
local RemotesFolder = game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
local remotes = RemotesFolder:WaitForChild("ClansRemotes")
local notifications = RemotesFolder:WaitForChild("Notifications")
local datastore = DataStoreService:GetDataStore("ClanData2")
local playerdatastore = DataStoreService:GetDataStore("PlayerClanMapping2")
local ALL_CLANS_KEY = "all_clans"
local ranks = {
	{name = "No Rank", image = "96185458434104"},
	{name = "Bronze", image = "109208951043936"},
	{name = "Silver", image = "71314645490028"},
	{name = "Gold", image = "102132573065326"},
	{name = "Platinum", image = "94167522823621"},
	{name = "Diamond", image = "107883485229888"},
	{name = "Champion", image = "75548832446020"},
	{name = "Legend", image = "90549151106795"}
}
local clantagtemplate = ServerStorage:WaitForChild("ClanTag")
local function getallclanids()
	local success, ids = pcall(function() return datastore:GetAsync(ALL_CLANS_KEY) end)
	if success and type(ids) == "table" then
		return ids
	end
	return {}
end
local function updateallclanids(ids)
	pcall(function() datastore:SetAsync(ALL_CLANS_KEY, ids) end)
end
local function updatepublicclans()
	local publicclans = {}
	local ids = getallclanids()
	for _, id in ipairs(ids) do
		local s, clan = pcall(function() return datastore:GetAsync(id) end)
		if s and type(clan) == "table" and clan.type == "public" then
			table.insert(publicclans, clan)
		end
	end
	for _, player in pairs(Players:GetPlayers()) do
		remotes.publicclansresponse:FireClient(player, publicclans)
	end
end
local function broadcastupdate()
	updatepublicclans()
	pcall(function() MessagingService:PublishAsync("ClanDataUpdate", "refresh") end)
end
pcall(function()
	MessagingService:SubscribeAsync("ClanDataUpdate", function(message)
		for _, player in pairs(Players:GetPlayers()) do
			local clanid = player:GetAttribute("clanid")
			if clanid then
				local s, clan = pcall(function() return datastore:GetAsync(clanid) end)
				if s and type(clan) == "table" then
					remotes.getclandata:FireClient(player, clan)
					remotes.updateclanmembers:FireClient(player, clan.members, clan.leader, clan.name, clan.image)
				end
			end
			local leaderboard = {}
			local ids = getallclanids()
			for _, id in ipairs(ids) do
				local s, clan = pcall(function() return datastore:GetAsync(id) end)
				if s and type(clan) == "table" and clan.members and #clan.members > 0 then
					table.insert(leaderboard, clan)
				end
			end
			table.sort(leaderboard, function(a, b)
				if a.rank == b.rank then
					return (a.xp or 0) > (b.xp or 0)
				else
					return a.rank > b.rank
				end
			end)
			local top10 = {}
			for i = 1, math.min(10, #leaderboard) do
				table.insert(top10, leaderboard[i])
			end
			remotes.clanleaderboardsresponse:FireClient(player, top10)
		end
	end)
end)
local function formatnumberwithcommas(number)
	local formatted = tostring(number)
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end
local function applyclantag(player, clan)
	local char = player.Character
	if char and char:FindFirstChild("Head") then
		local head = char.Head
		if head:FindFirstChild("ClanTag") then head.ClanTag:Destroy() end
		local tag = clantagtemplate:Clone()
		tag.Parent = head
		tag.Enabled = true
		tag.Name = "ClanTag"
		if tag:FindFirstChild("ClanName") then tag.ClanName.Text = clan.name end
		if tag:FindFirstChild("ClanImage") then tag.ClanImage.Image = "rbxassetid://" .. clan.image end
	end
end
local function removeclantag(player)
	local char = player.Character
	if char and char:FindFirstChild("Head") then
		local head = char.Head
		if head:FindFirstChild("ClanTag") then head.ClanTag:Destroy() end
	end
end
local function generateclanid()
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local id
	local ids = getallclanids()
	local function exists(id)
		for _, v in ipairs(ids) do
			if v == id then
				return true
			end
		end
		return false
	end
	repeat
		id = ""
		for i = 1, 7 do
			local index = math.random(1, #chars)
			id = id .. chars:sub(index, index)
		end
	until not exists(id)
	return id
end
local function saveclandata(clanid, clandata)
	if clandata.members and type(clandata.members) == "table" then
		clandata.memberCount = #clandata.members
	else
		clandata.memberCount = 0
	end
	pcall(function() datastore:SetAsync(clanid, clandata) end)
	broadcastupdate()
end
local function saveplayerclan(player, clanid)
	pcall(function() playerdatastore:SetAsync(tostring(player.UserId), clanid) end)
end
local function removeplayerclan(player)
	pcall(function() playerdatastore:RemoveAsync(tostring(player.UserId)) end)
end
local function loadplayerclan(player)
	local savedclanid
	local success = pcall(function() savedclanid = playerdatastore:GetAsync(tostring(player.UserId)) end)
	if success and savedclanid and savedclanid ~= "" then
		player:SetAttribute("clanid", savedclanid)
		local s, clandata = pcall(function() return datastore:GetAsync(savedclanid) end)
		if s and type(clandata) == "table" then
			clandata.xp = clandata.xp or 0
			clandata.rank = clandata.rank or 1
			clandata.rankname = clandata.rankname or ranks[clandata.rank].name
			clandata.rankimage = clandata.rankimage or ranks[clandata.rank].image
			clandata.lastreset = clandata.lastreset or os.time()
			if not clandata.type then clandata.type = "private" end
			remotes.getclandata:FireClient(player, clandata)
			remotes.updateclanmembers:FireClient(player, clandata.members, clandata.leader, clandata.name, clandata.image, clandata.maxmembers)
			applyclantag(player, clandata)
			remotes.getclandata:FireClient(player, clandata)
		else
			player:SetAttribute("clanid", nil)
			removeplayerclan(player)
			removeclantag(player)
		end
	end
end
Players.PlayerAdded:Connect(function(player)
	loadplayerclan(player)
	player.CharacterAdded:Connect(function(character)
		wait(1)
		local clanid = player:GetAttribute("clanid")
		if clanid then
			local s, clan = pcall(function() return datastore:GetAsync(clanid) end)
			if s and type(clan) == "table" then
				applyclantag(player, clan)
			end
		end
	end)
end)
local function createclan(player, name, image, visibility)
	local originalname = name
	if not RunService:IsStudio() then
		local success, filteredresult = pcall(function() return TextService:FilterStringAsync(name, player.UserId) end)
		local safename = filteredresult:GetNonChatStringForBroadcastAsync()
		if safename ~= originalname then
			notifications.Client:FireClient(player, "Inappropriate clan name.", "Error", 5)
			remotes.createclanresponse:FireClient(player, false)
			return false
		end
		name = safename
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats or not leaderstats:FindFirstChild("Time") or leaderstats.Time.Value < 50000000 then
		notifications.Client:FireClient(player, "You need at least 50,000,000 Time to create a clan.", "Error", 5)
		remotes.createclanresponse:FireClient(player, false)
		return false
	end
	leaderstats.Time.Value = leaderstats.Time.Value - 50000000
	local clanid = generateclanid()
	local clan = {
		id = clanid,
		name = name,
		image = image,
		leader = player.UserId,
		members = {player.UserId},
		maxmembers = 10,
		increaselimitcost = 25000000,
		xp = 0,
		rank = 1,
		rankname = ranks[1].name,
		rankimage = ranks[1].image,
		lastreset = os.time(),
		type = visibility
	}
	saveclandata(clanid, clan)
	saveplayerclan(player, clanid)
	local ids = getallclanids()
	table.insert(ids, clanid)
	updateallclanids(ids)
	player:SetAttribute("clanid", clanid)
	notifications.Client:FireClient(player, "Clan created successfully!", "Success", 5)
	remotes.getclandata:FireClient(player, clan)
	remotes.createclanresponse:FireClient(player, true)
	applyclantag(player, clan)
	broadcastupdate()
	return true
end
remotes.createclan.OnServerEvent:Connect(createclan)
local function joinclan(player, id)
	if player:GetAttribute("clanid") then
		notifications.Client:FireClient(player, "You are already in a clan.", "Error", 5)
		remotes.joinclanresponse:FireClient(player, false)
		return false
	end
	local s, clan = pcall(function() return datastore:GetAsync(id) end)
	if not s or type(clan) ~= "table" or #clan.members >= clan.maxmembers then
		notifications.Client:FireClient(player, "Unable to join the clan.", "Error", 5)
		remotes.joinclanresponse:FireClient(player, false)
		return false
	end
	table.insert(clan.members, player.UserId)
	saveclandata(id, clan)
	saveplayerclan(player, id)
	player:SetAttribute("clanid", id)
	notifications.Client:FireClient(player, "Joined clan successfully!", "Success", 5)
	remotes.joinclanresponse:FireClient(player, true)
	applyclantag(player, clan)
	broadcastupdate()
	return true
end
remotes.joinclan.OnServerEvent:Connect(joinclan)
local function leaveclan(player)
	local clanid = player:GetAttribute("clanid")
	if not clanid then
		notifications.Client:FireClient(player, "You are not in a clan.", "Error", 5)
		remotes.leaveclanresponse:FireClient(player, false)
		return false
	end
	local s, clan = pcall(function() return datastore:GetAsync(clanid) end)
	if not s or type(clan) ~= "table" then
		notifications.Client:FireClient(player, "Clan data error.", "Error", 5)
		remotes.leaveclanresponse:FireClient(player, false)
		return false
	end
	for i, member in ipairs(clan.members) do
		if member == player.UserId then
			table.remove(clan.members, i)
			break
		end
	end
	player:SetAttribute("clanid", nil)
	removeplayerclan(player)
	saveclandata(clanid, clan)
	notifications.Client:FireClient(player, "Left clan successfully.", "Success", 5)
	remotes.leaveclanresponse:FireClient(player, true)
	removeclantag(player)
	if #clan.members == 0 then
		pcall(function() datastore:RemoveAsync(clanid) end)
		local ids = getallclanids()
		for i, v in ipairs(ids) do
			if v == clanid then
				table.remove(ids, i)
				break
			end
		end
		updateallclanids(ids)
	else
		remotes.updateclanmembers:FireClient(player, clan.members, clan.leader, clan.name, clan.image, clan.maxmembers)
	end
	broadcastupdate()
	return true
end
remotes.leaveclan.OnServerEvent:Connect(leaveclan)
local function increasememberlimit(player)
	local clanid = player:GetAttribute("clanid")
	if not clanid then
		notifications.Client:FireClient(player, "You are not in a clan.", "Error", 5)
		remotes.increasememberlimitresponse:FireClient(player, false)
		return false
	end
	local s, clan = pcall(function() return datastore:GetAsync(clanid) end)
	if not s or type(clan) ~= "table" or clan.leader ~= player.UserId then
		notifications.Client:FireClient(player, "You are not the clan leader.", "Error", 5)
		remotes.increasememberlimitresponse:FireClient(player, false)
		return false
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if clan.maxmembers >= 17 then
		notifications.Client:FireClient(player, "Maximum member limit reached.", "Error", 5)
		remotes.increasememberlimitresponse:FireClient(player, false)
		return false
	end
	local cost = clan.increaselimitcost
	if not leaderstats or not leaderstats:FindFirstChild("Time") or leaderstats.Time.Value < cost then
		notifications.Client:FireClient(player, "Not enough Time to increase limit. Cost: " .. formatnumberwithcommas(cost), "Error", 5)
		remotes.increasememberlimitresponse:FireClient(player, false)
		return false
	end
	leaderstats.Time.Value = leaderstats.Time.Value - cost
	clan.maxmembers = clan.maxmembers + 1
	clan.increaselimitcost = clan.increaselimitcost * 2
	saveclandata(clanid, clan)
	notifications.Client:FireClient(player, "Member limit increased! New limit: " .. clan.maxmembers, "Success", 5)
	remotes.increasememberlimitresponse:FireClient(player, true)
	remotes.getclandata:FireClient(player, clan)
	broadcastupdate()
	return true
end
remotes.increasememberlimit.OnServerEvent:Connect(increasememberlimit)
local function requestclanmembers(player)
	local clanid = player:GetAttribute("clanid")
	if clanid then
		local s, clan = pcall(function() return datastore:GetAsync(clanid) end)
		if s and type(clan) == "table" then
			remotes.updateclanmembers:FireClient(player, clan.members, clan.leader, clan.name, clan.image)
		end
	end
end
remotes.requestclanmembers.OnServerEvent:Connect(requestclanmembers)
local function regenerateclanid(player)
	local oldid = player:GetAttribute("clanid")
	if not oldid then
		notifications.Client:FireClient(player, "You are not in a clan.", "Error", 5)
		return
	end
	local s, clan = pcall(function() return datastore:GetAsync(oldid) end)
	if not s or type(clan) ~= "table" or clan.leader ~= player.UserId then
		notifications.Client:FireClient(player, "Only the clan leader can regenerate the ID.", "Error", 5)
		return
	end
	local newid = generateclanid()
	clan.id = newid
	saveclandata(newid, clan)
	pcall(function() datastore:RemoveAsync(oldid) end)
	local ids = getallclanids()
	for i, v in ipairs(ids) do
		if v == oldid then
			ids[i] = newid
			break
		end
	end
	updateallclanids(ids)
	for _, plr in pairs(Players:GetPlayers()) do
		if plr:GetAttribute("clanid") == oldid then
			plr:SetAttribute("clanid", newid)
			saveplayerclan(plr, newid)
			remotes.getclandata:FireClient(plr, clan)
			remotes.updateclanmembers:FireClient(plr, clan.members, clan.leader, clan.name, clan.image)
			applyclantag(plr, clan)
		end
	end
	remotes.regeneratedclanid:FireClient(player, newid)
	broadcastupdate()
end
remotes.regenerateclanid.OnServerEvent:Connect(regenerateclanid)
local function kickmember(player, targetuserid)
	local clanid = player:GetAttribute("clanid")
	if not clanid then
		notifications.Client:FireClient(player, "You are not in a clan.", "Error", 5)
		return
	end
	local s, clan = pcall(function() return datastore:GetAsync(clanid) end)
	if not s or type(clan) ~= "table" or clan.leader ~= player.UserId then
		notifications.Client:FireClient(player, "Only the clan leader can kick members.", "Error", 5)
		return
	end
	if targetuserid == player.UserId then
		notifications.Client:FireClient(player, "You cannot kick yourself.", "Error", 5)
		return
	end
	local kicked = false
	for i, member in ipairs(clan.members) do
		if member == targetuserid then
			table.remove(clan.members, i)
			kicked = true
			break
		end
	end
	if not kicked then
		notifications.Client:FireClient(player, "Member not found.", "Error", 5)
		return
	end
	saveclandata(clanid, clan)
	notifications.Client:FireClient(player, "Member kicked successfully.", "Success", 5)
	remotes.updateclanmembers:FireClient(player, clan.members, clan.leader, clan.name, clan.image, clan.maxmembers)
	for _, plr in pairs(Players:GetPlayers()) do
		if plr.UserId == targetuserid then
			plr:SetAttribute("clanid", nil)
			removeplayerclan(plr)
			notifications.Client:FireClient(plr, "You have been kicked from the clan.", "Error", 5)
			remotes.leaveclanresponse:FireClient(plr, true)
			removeclantag(plr)
			break
		end
	end
	broadcastupdate()
end
remotes.kickmember.OnServerEvent:Connect(kickmember)
local function updateclanxp(player, amount)
	local clanid = player:GetAttribute("clanid")
	if not clanid then return end
	local s, clan = pcall(function() return datastore:GetAsync(clanid) end)
	if s and type(clan) == "table" then
		clan.xp = (clan.xp or 0) + amount
		while clan.xp >= 1500 and clan.rank < #ranks do
			clan.xp = clan.xp - 1500
			clan.rank = clan.rank + 1
			clan.rankname = ranks[clan.rank].name
			clan.rankimage = ranks[clan.rank].image
		end
		saveclandata(clanid, clan)
		remotes.getclandata:FireClient(player, clan)
		remotes.updateclanmembers:FireClient(player, clan.members, clan.leader, clan.name, clan.image)
		broadcastupdate()
	end
end
_G.updateclanxp = updateclanxp
local function getpublicclans(player)
	local publicclans = {}
	local ids = getallclanids()
	for _, id in ipairs(ids) do
		local s, clan = pcall(function() return datastore:GetAsync(id) end)
		if s and type(clan) == "table" and clan.type == "public" then
			table.insert(publicclans, clan)
		end
	end
	remotes.publicclansresponse:FireClient(player, publicclans)
end
remotes.getpublicclans.OnServerEvent:Connect(getpublicclans)
local function getclanleaderboards(player)
	local leaderboard = {}
	local ids = getallclanids()
	for _, id in ipairs(ids) do
		local s, clan = pcall(function() return datastore:GetAsync(id) end)
		if s and type(clan) == "table" and clan.members and #clan.members > 0 then
			table.insert(leaderboard, clan)
		end
	end
	table.sort(leaderboard, function(a, b)
		if a.rank == b.rank then
			return (a.xp or 0) > (b.xp or 0)
		else
			return a.rank > b.rank
		end
	end)
	local top10 = {}
	for i = 1, math.min(10, #leaderboard) do
		table.insert(top10, leaderboard[i])
	end
	remotes.clanleaderboardsresponse:FireClient(player, top10)
end
remotes.getclanleaderboards.OnServerEvent:Connect(getclanleaderboards)
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		if msg:lower() == ".clanxpreset" then
			if player:GetRankInGroup(35360112) >= 252 then
				local ids = getallclanids()
				for _, id in ipairs(ids) do
					local s, clan = pcall(function() return datastore:GetAsync(id) end)
					if s and type(clan) == "table" then
						clan.xp = 0
						clan.rank = 1
						clan.rankname = ranks[1].name
						clan.rankimage = ranks[1].image
						saveclandata(id, clan)
						for _, plr in pairs(Players:GetPlayers()) do
							if plr:GetAttribute("clanid") == id then
								remotes.getclandata:FireClient(plr, clan)
								remotes.updateclanmembers:FireClient(plr, clan.members, clan.leader, clan.name, clan.image)
							end
						end
					end
				end
				notifications.Client:FireAllClients("All clan XP and ranks have been reset.", "Success", 5)
				broadcastupdate()
			else
				notifications.Client:FireClient(player, "You do not have permission to use this command.", "Error", 5)
			end
		end
	end)
end)
game:BindToClose(function()
	local ids = getallclanids()
	for _, id in ipairs(ids) do
		pcall(function() datastore:SetAsync(id, datastore:GetAsync(id)) end)
	end
end)
