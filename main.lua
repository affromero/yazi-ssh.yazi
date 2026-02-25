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

--- Check if running inside an SSH session started by yazi-ssh wrapper.
local function is_ssh_mode()
	return os.getenv("YAZI_SSH_QUEUE") ~= nil
end

--- Resolve a local path to user@host:path format in SSH mode.
--- Paths are already real server paths (yazi runs on the server),
--- so we just prepend the remote host prefix.
local function resolve_remote_path(local_path)
	local remote = os.getenv("YAZI_SSH_REMOTE")
	if not remote then
		return local_path
	end
	return remote .. ":" .. local_path
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

-- ------------------------------------------------------------------
-- SHELL HELPERS
-- ------------------------------------------------------------------

local function shell_escape(s)
	return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- ------------------------------------------------------------------
-- DOWNLOAD
-- ------------------------------------------------------------------

--- Queue remote paths for download by appending to the queue file.
--- The wrapper's watcher process picks them up and runs scp.
local function queue_for_download(sources, queue_path)
	local ok, fail = 0, 0
	for _, src in ipairs(sources) do
		local cmd = "printf '%s\\n' " .. shell_escape(src) .. " >> " .. shell_escape(queue_path)
		local output = Command("sh"):args({ "-c", cmd }):stderr(Command.PIPED):output()
		if output and output.status and output.status.code == 0 then
			ok = ok + 1
		else
			fail = fail + 1
		end
	end
	return ok, fail
end

--- Copy *sources* (list of absolute paths) into *dl_dir* (local mode).
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
		local queue_path = os.getenv("YAZI_SSH_QUEUE")

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
			local ok, fail, msg

			if ssh and queue_path then
				ok, fail = queue_for_download(state.selected, queue_path)
				if fail == 0 then
					msg = ok .. " item(s) queued for download"
				else
					msg = ok .. " queued, " .. fail .. " failed to queue"
				end
			else
				local dl_dir = os.getenv("YAZI_SSH_DOWNLOAD_DIR")
					or os.getenv("HOME") .. "/Downloads"
				ok, fail = download_items(state.selected, dl_dir)
				if fail == 0 then
					msg = ok .. " item(s) downloaded to " .. dl_dir
				else
					msg = ok .. " downloaded, " .. fail .. " failed"
				end
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
