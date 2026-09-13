local net = require("@lune/net")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local datetime = require("@lune/datetime")

type WeaoExploit = { title: string, platform: string, version: string }

local function fetchCurrentVersion(): string
	local request = net.request("https://weao.gg/api/status/exploits")
	if not request.ok then
		error(`failed to fetch version: {request.statusCode} {request.statusMessage}`)
	end
	local exploits = serde.decode("json", request.body) :: { types.WeaoExploit }
	for _, exploit in exploits do
		if exploit.title == "Delta" and exploit.platform == "iOS" then
			return tostring(exploit.version)
		end
	end
	error("Delta iOS entry not found in weao exploits list")
end

local function getRemoteSize(url: string): number?
	local ok, result = pcall(net.request, {
		url = url,
		method = "HEAD",
	})
	if not ok then
		return nil
	end
	local response = result :: any
	if not response.ok then
		return nil
	end
	local raw = response.headers["content-length"] or response.headers["Content-Length"]
	if typeof(raw) == "table" then
		raw = (raw :: any)[1]
	end
	if typeof(raw) ~= "string" then
		return nil
	end
	return tonumber(raw :: string)
end

-- Build source.json from template.json, accumulating versions (no overwrite)
local version = fetchCurrentVersion()
local date = datetime.now():toRfc3339()

local source = serde.decode("json", fs.readFile("template.json")) :: any

local function writeOutputs(body: string)
	fs.writeFile("source.json", body)
	-- Stage GitHub Pages artifact (public/ is gitignored, rebuilt every run)
	if not fs.isDir("public") then
		fs.writeDir("public")
	end
	fs.writeFile("public/source.json", body)
	fs.writeFile("public/.nojekyll", "")
end

-- Load existing versions from previous build, if any
local existingVersions: { any } = {}
if fs.isFile("source.json") then
	local ok, decoded = pcall(function()
		return serde.decode("json", fs.readFile("source.json"))
	end)
	if ok and typeof(decoded) == "table" then
		local apps = (decoded :: any).apps
		if typeof(apps) == "table" and typeof(apps[1]) == "table" and typeof(apps[1].versions) == "table" then
			existingVersions = apps[1].versions
		end
	end
end

-- Skip if this version is already recorded
for _, entry in existingVersions do
	if typeof(entry) == "table" and (entry :: any).version == version then
		source.apps[1].versions = existingVersions
		writeOutputs(serde.encode("json", source))
		print(`Source already up to date with Delta v{version} ({#existingVersions} versions)`)
		return
	end
end

local downloadURL = `https://cdn.glopdelivery.com/file/Delta-{version}.ipa`

local remoteSize = getRemoteSize(downloadURL)
if remoteSize == nil then
	print(`warn: could not determine size for {downloadURL}, defaulting to 0`)
end

local versionEntry = {
	downloadURL = downloadURL,
	size = remoteSize or 0,
	version = version,
	date = date,
	localizedDescription = `- Updated to version {version}\n- Refer to the official Discord/Telegram for the actual updates.`,
}

-- Prepend newest version, keep history
table.insert(existingVersions, 1, versionEntry)
source.apps[1].versions = existingVersions

writeOutputs(serde.encode("json", source))
print(`Built source with Delta v{version} ({#existingVersions} versions)`)
