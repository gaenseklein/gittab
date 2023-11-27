VERSION = "1.0.0"

local micro = import("micro")
local config = import("micro/config")
local shell = import("micro/shell")
local buffer = import("micro/buffer")

-- internal vars we need
local inside_git = false

-- we need some storage

local unstaged_files = {}
local staged_files = {}
local logs = {}

local line_actions = {}
local interactive_lines = {}

local fileview = nil

local txt = {
	unstaged_changes = "unstaged changes",
	staged_changes = "staged changes",
	commit_message = "commit-message",
	logs = "logs",
	pre_log_date_symbol = "★ ",
	pre_log_comment_symbol = "> ",
	
}

local function build_staged_unstaged_lists()
	unstaged_files = {}
	staged_files = {}
	local raw = shell.RunCommand('git status -s')
	local spos = 1
	local epos = string.find(raw, '\n',spos)
	while epos ~= nil do
		local line = string.sub(raw, spos, epos-1)
		local path = string.sub(line, 4)
		local unstaged = string.sub(line,1,1)
		local staged = string.sub(line,2,2)
		if unstaged == 'D' then
			table.insert(unstaged_files,{
				path = path,
				deleted = true,
				pre = unstaged
			})
		elseif unstaged == 'M' then
			table.insert(unstaged_files,{
						path = path,
						modified = true,
						pre = unstaged
					})
		elseif unstaged == '?' and string.sub(path,-1) ~= '/' then
			table.insert(unstaged_files,{
							path = path,
							isnew = true,
							pre = unstaged
						})
		end

		if staged == 'D' then
			table.insert(staged_files,{
							path = path,
							deleted = true,
							pre = staged
						})
		elseif staged == 'M' then
			table.insert(staged_files,{
							path = path,
							modified = true,
							pre = staged
						})
		elseif staged == 'A' then
			table.insert(staged_files,{
							path = path,
							isnew = true,
							pre = staged
						})
		end
		
		spos = epos + 1
		epos = string.find(raw, '\n',spos)
	end
	--sort the tables by path:
	table.sort(unstaged_files, function (a,b) return a.path < b.path end)
	table.sort(staged_files, function(a,b) return a.path < b.path end)
end




local function get_logs(more)
	local cmd = 'git log --max-count 100'
	if more == nil then
		-- we start to get new logs
		logs = {}
	end
	local raw = shell.RunCommand(cmd)

	local spos = 1
	local epos = string.find(raw, '\n', spos)
	local actobj = {}
	while epos ~= nil do
		local line = string.sub(raw,spos, epos-1)
		local begin = string.sub(line,1,6)
		if begin == 'commit' then
			table.insert(logs,actobj)
			actobj = {
				commit = line
			}
		elseif begin == 'Author' then
			actobj.author = string.sub(line,9)
		elseif begin == 'Date: ' then
			actobj.date = string.sub(line,9)
		elseif #line > 4 then
			if actobj.log == nil then
				actobj.log = {string.sub(line,5)}
			else
				table.insert(actobj.log, string.sub(line,5))
			end
		end
		
		spos = epos + 1
		epos = string.find(raw, '\n', spos)
	end
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Display
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

function print_line(linenr, linetext)
	fileview.Buf.EventHandler:Insert(buffer.Loc(0,linenr), linetext .. '\n')
end

local function print_unstaged(startline)
	local l = startline
	print_line(l, '### ' .. #unstaged_files .. ' ' ..txt.unstaged_changes .. ' ###')
	l = l + 1
	for i=1, #unstaged_files do
		print_line(l, unstaged_files[i].pre .. '  ' .. unstaged_files[i].path)
		line_actions[l] = {file= true, unstaged=true, path= unstaged_files[i].path, index=i}
		table.insert(interactive_lines, l)
		l = l + 1
	end
	return l
end

local function print_staged(startline)
	local l = startline
		print_line(l, '### '.. #staged_files .. ' '.. txt.staged_changes .. ' ###')
		l = l + 1
		for i=1, #staged_files do
			print_line(l, staged_files[i].pre .. '  ' .. staged_files[i].path)
			line_actions[l] = {file= true, staged=true, path=staged_files[i].path, index=i}
			table.insert(interactive_lines, l)
			l = l + 1
		end
		return l
end

local function print_commit_block(startline)
	local l = startline
	print_line(l, '### '.. txt.commit_message .. ' ###')
	print_line(l+1,'')
	print_line(l+2, '[commit]')
	l = l + 3
	return l
end

local function print_log_block(startline)
	local l = startline
	print_line(l, '### '.. #logs .. ' ' .. txt.logs .. ' ###')
	l = l + 1
	-- local logstring = dump(logs)
	-- print_line(l, logstring)
	for i=1,#logs do
		if logs[i].date ~= nil then 
			print_line(l, txt.pre_log_date_symbol .. logs[i].date)
			l = l + 1
			for ii=1, #logs[i].log do
				print_line(l, txt.pre_log_comment_symbol .. logs[i].log[ii])
				l = l + 1
			end
			print_line(l,'---------------')
			l = l+1
		end
	end
	return l
end



local function display()
	local count = 1
	line_actions = {}
	interactive_lines = {}	
	fileview.Buf.EventHandler:Remove(fileview.Buf:Start(), fileview.Buf:End())
	count = print_unstaged(count)
	count = print_staged(count)
	count = print_commit_block(count)
	count = print_log_block(count)
	local unstaged_begin = interactive_lines[1]
	if unstaged_begin == nil then unstaged_begin = 1 end
	fileview:GotoCmd({unstaged_begin..''})
end

-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- init stuff
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


local function init_view()
	local actview = micro.CurPane()
	if target_pane == nil or actview ~= fileview then
		target_pane = actview
	
	end
	micro.CurPane():VSplitIndex(buffer.NewBuffer("", "gittab"), true)
	fileview = micro.CurPane()
	fileview:ResizePane(30) -- does not lock, will be changed after vsplit!
	fileview.Buf.Type.Scratch = true
	fileview.Buf:SetOptionNative("softwrap", false)
	fileview.Buf:SetOptionNative("ruler", false)
	fileview.Buf:SetOptionNative("autosave", false)
	fileview.Buf:SetOptionNative("statusformatr", "")
	fileview.Buf:SetOptionNative("statusformatl", "git")
	fileview.Buf:SetOptionNative("scrollbar", false)
	fileview.Buf:SetOptionNative("filetype","gittab")
end

local function close_view()
	if fileview ~= nil then
		fileview:Quit()
		fileview = nil
		--clear_messenger()
	end
end



function init()
	local test_git = shell.RunCommand('git rev-parse --is-inside-work-tree')
	inside_git = (string.sub(test_git,1,4) == 'true')
	config.MakeCommand("gittab", micro_command, config.NoComplete)
	config.AddRuntimeFile("gittab", config.RTSyntax, "syntax.yaml")						
end
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- user actions
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- command "gittab" 
function micro_command(bp, args)
	if fileview == nil then init_view() end
	build_staged_unstaged_lists()
	get_logs()
	display()
end


-- Close current
function preQuit(view)
	if view == fileview then
		-- A fake quit function
		close_view()
		-- Don't actually "quit", otherwise it closes everything without saving for some reason
		return false
	end
end


-- Close all
function preQuitAll(view)
	close_view()
end

-- handle normal keystrokes on fileview pane:
function preRune(view, r)
	if view ~= fileview then 
		return true 
	end
	if r=='i' then 
		show_ignored = not show_ignored
		display_tree()
	end	
	return false
end

-- handle enter on search result
function preInsertNewline(view)
    if view == fileview then
    	--handle_click()
        return false
    end
    return true
end

function onEscape(view)
	if view == fileview then 
		close_view()
	end
end


-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- dirty little helpers
-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~


function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

