local net = require("@lune/net")
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local datetime = require("@lune/datetime")
local process = require("@lune/process")

type WeaoExploit = { title: string, platform: string, version: string }

-- Pages base URL: explicit override wins, then GITHUB_REPOSITORY (owner/repo),
-- then canonical fallback. Keeps forks working without editing template.json.
local DEFAULT_BASE_URL = "https://jacklebeignet.github.io/delta-altstore-source"

local function resolveBaseUrl(): string
	local ok, env = pcall(function()
		return process.env
	end)
	if ok and typeof(env) == "table" then
		local explicit = (env :: any).PAGES_BASE_URL
		if typeof(explicit) == "string" and #explicit > 0 then
			return (string.gsub(explicit, "/$", ""))
		end
		local repo = (env :: any).GITHUB_REPOSITORY
		if typeof(repo) == "string" then
			local owner, name = string.match(repo, "^([^/]+)/([^/]+)$")
			if owner and name then
				return `https://{owner}.github.io/{name}`
			end
		end
	end
	return DEFAULT_BASE_URL
end

-- Vendored images: committed under assets/, published via Pages at /assets/.
-- Remote URLs are only a fallback to re-seed assets/ on fresh clones.
local ASSETS: { { file: string, remote: string } } = {
	{ file = "logo.webp", remote = "https://cdn.weao.gg/slug/delta/logo.png" },
	{ file = "icon.png", remote = "https://i.imgur.com/r3JSqGc.png" },
	{ file = "screenshot1.png", remote = "https://cdn.weao.gg/slug/delta/screenshot1.png" },
	{ file = "screenshot2.png", remote = "https://cdn.weao.gg/slug/delta/screenshot2.png" },
	{ file = "screenshot3.png", remote = "https://cdn.weao.gg/slug/delta/screenshot3.png" },
	{ file = "screenshot4.png", remote = "https://cdn.weao.gg/slug/delta/screenshot4.png" },
}

local function syncAssets()
	if not fs.isDir("assets") then
		fs.writeDir("assets")
	end
	if not fs.isDir("public") then
		fs.writeDir("public")
	end
	if not fs.isDir("public/assets") then
		fs.writeDir("public/assets")
	end
	for _, entry in ASSETS do
		local localPath = `assets/{entry.file}`
		local publicPath = `public/assets/{entry.file}`
		-- Re-seed missing vendored file from upstream (fresh clone safety net)
		if not fs.isFile(localPath) then
			local res = net.request(entry.remote)
			if not res.ok then
				error(`failed to download asset {entry.remote}: {res.statusCode}`)
			end
			fs.writeFile(localPath, res.body)
			print(`seeded {localPath} from upstream`)
		end
		-- Stage for Pages (byte copy; Luau strings are 8-bit clean)
		fs.writeFile(publicPath, fs.readFile(localPath))
	end
end

local function pointUrlsAtPages(source: any, baseUrl: string)
	source.iconURL = `{baseUrl}/assets/logo.webp`
	(source.apps[1] :: any).iconURL = `{baseUrl}/assets/icon.png`
	local screenshots = (source.apps[1] :: any).screenshots
	if typeof(screenshots) == "table" then
		for i, shot in screenshots do
			if typeof(shot) == "table" then
				(shot :: any).imageURL = `{baseUrl}/assets/screenshot{i}.png`
			end
		end
	end
end

local function fetchCurrentVersion(): string
	local request = net.request("https://weao.gg/api/status/exploits")
	if not request.ok then
		error(`failed to fetch version: {request.statusCode} {request.statusMessage}`)
	end
	local exploits = serde.decode("json", request.body) :: { WeaoExploit }
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
local baseUrl = resolveBaseUrl()

local source = serde.decode("json", fs.readFile("template.json")) :: any
pointUrlsAtPages(source, baseUrl)
syncAssets()

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
