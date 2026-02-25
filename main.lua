--- @since 25.2.26

-- ------------------------------------------------------------------
-- SYNC HELPERS (access yazi state from async context)
-- ------------------------------------------------------------------

local get_state = ya.sync(function()
	local h = cx.active.current.hovered
	if not h then
		return nil
	end

	local cwd = tostring(cx.active.current.cwd)
	local url = tostring(h.url)
	local name = h.name
	local is_dir = h.cha.is_dir

	-- Collect selected files; fall back to hovered
	local selected = {}
	for _, sel_url in pairs(cx.active.selected) do
		selected[#selected + 1] = tostring(sel_url)
	end
	if #selected == 0 then
		selected = { url }
	end

	return {
		url = url,
		cwd = cwd,
		name = name,
		is_dir = is_dir,
		selected = selected,
	}
end)

-- ------------------------------------------------------------------
-- PATH HELPERS
-- ------------------------------------------------------------------

--- Resolve a local sshfs mount path to the real remote path.
--- Returns the original path unchanged when not in SSH mode.
local function resolve_remote_path(local_path)
	local mount = os.getenv("YAZI_SSH_MOUNT")
	local remote = os.getenv("YAZI_SSH_REMOTE")
	local remote_base = os.getenv("YAZI_SSH_REMOTE_PATH") or ""

	if not mount or not remote then
		return local_path
	end

	-- Strip the mount prefix to get the relative portion
	local relative = ""
	if #local_path > #mount then
		relative = local_path:sub(#mount + 2) -- +2 skips the trailing /
	end

	if remote_base ~= "" then
		if relative ~= "" then
			return remote .. ":" .. remote_base .. "/" .. relative
		end
		return remote .. ":" .. remote_base
	end

	if relative ~= "" then
		return remote .. ":~/" .. relative
	end
	return remote .. ":"
end

--- Return *path* relative to *cwd* (pure string prefix strip).
local function get_relative_path(url, cwd)
	if url:sub(1, #cwd) == cwd then
		local rel = url:sub(#cwd + 2)
		if rel == "" then
			return "."
		end
		return rel
	end
	return url
end

local function is_ssh_mode()
	return os.getenv("YAZI_SSH_MOUNT") ~= nil
end

local function get_download_dir()
	return os.getenv("YAZI_SSH_DOWNLOAD_DIR")
		or os.getenv("HOME") .. "/Downloads"
end

-- ------------------------------------------------------------------
-- DOWNLOAD
-- ------------------------------------------------------------------

--- Copy *sources* (list of absolute paths) into *dl_dir*.
--- Returns success_count, fail_count.
local function download_items(sources, dl_dir)
	-- Ensure destination exists
	Command("mkdir"):args({ "-p", dl_dir }):output()

	local ok, fail = 0, 0
	for _, src in ipairs(sources) do
		local output = Command("cp")
			:args({ "-r", src, dl_dir .. "/" })
			:stderr(Command.PIPED)
			:output()

		if output and output.status and output.status.code == 0 then
			ok = ok + 1
		else
			fail = fail + 1
		end
	end
	return ok, fail
end

-- ------------------------------------------------------------------
-- ENTRY
-- ------------------------------------------------------------------

return {
	entry = function(self, job)
		local state = get_state()
		if not state then
			ya.notify({
				title = "Context Menu",
				content = "No file hovered",
				timeout = 2,
				level = "warn",
			})
			return
		end

		local ssh = is_ssh_mode()
		local dl_dir = get_download_dir()

		local cands = {
			{ on = "o", desc = "Open" },
			{ on = "O", desc = "Open with\u{2026}" },
			{ on = "c", desc = ssh and "Copy remote path" or "Copy absolute path" },
			{ on = "r", desc = "Copy relative path" },
			{ on = "n", desc = "Copy filename" },
			{ on = "d", desc = "Download" },
		}

		local idx = ya.which({ cands = cands })
		if not idx then
			return
		end

		local action = cands[idx].on

		-- --------------------------------------------------------
		-- Open
		-- --------------------------------------------------------
		if action == "o" then
			if state.is_dir then
				ya.emit("enter", {})
			else
				ya.emit("open", {})
			end

		-- --------------------------------------------------------
		-- Open with picker
		-- --------------------------------------------------------
		elseif action == "O" then
			ya.emit("open", { interactive = true })

		-- --------------------------------------------------------
		-- Copy absolute / remote path
		-- --------------------------------------------------------
		elseif action == "c" then
			local path = ssh and resolve_remote_path(state.url) or state.url
			ya.clipboard(path)
			ya.notify({
				title = "Copied",
				content = path,
				timeout = 3,
				level = "info",
			})

		-- --------------------------------------------------------
		-- Copy relative path
		-- --------------------------------------------------------
		elseif action == "r" then
			local rel = get_relative_path(state.url, state.cwd)
			ya.clipboard(rel)
			ya.notify({
				title = "Copied",
				content = rel,
				timeout = 3,
				level = "info",
			})

		-- --------------------------------------------------------
		-- Copy filename
		-- --------------------------------------------------------
		elseif action == "n" then
			ya.clipboard(state.name)
			ya.notify({
				title = "Copied",
				content = state.name,
				timeout = 3,
				level = "info",
			})

		-- --------------------------------------------------------
		-- Download
		-- --------------------------------------------------------
		elseif action == "d" then
			local ok, fail = download_items(state.selected, dl_dir)

			local msg
			if fail == 0 then
				msg = ok .. " item(s) downloaded to " .. dl_dir
			else
				msg = ok .. " downloaded, " .. fail .. " failed"
			end
			ya.notify({
				title = "Download",
				content = msg,
				timeout = 3,
				level = fail > 0 and "error" or "info",
			})
		end
	end,
}
