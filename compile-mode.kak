# Initialization
hook global WinSetOption filetype=compiler %{
    require-module compiler
}

hook -group compiler-highlight global WinSetOption filetype=compiler %{
    add-highlighter window/compiler ref compiler
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/comoiler }

    map window normal <ret> ':parse-err-msg <ret>'
    map window user q ':db <ret>'

}

require-module luar
provide-module compiler %§

# Syntax highlighting
add-highlighter shared/compiler regions
add-highlighter shared/compiler/code default-region group
add-highlighter shared/compiler/code/ regex "[a-zA-Z0-9_\-\./]+\.[a-zA-Z0-9]+(:|\()[0-9]+" 0:value

# Keywords
add-highlighter shared/compiler/code/ regex \b(error|Error|ERROR|warning|Warning|WARNING|note|Note|NOTE)\b 0:keyword
add-highlighter shared/compiler/code/ regex "\*Compilation\*" 0:function

define-command -hidden open-file-mode -params 1 %{
	lua %arg{1} %val{reg_m} %{
		local patterns = {
			grep = {"([a-zA-Z0-9_\\-/\\.]+\\.[a-zA-Z0-9]+):(\\d+)", false},
			lua  = {"([a-zA-Z0-9_\\-/\\.]+\\.[a-zA-Z0-9]+):(\\d+)", false},
			ssa  = {"([a-zA-Z0-9_\\-/\\.]+\\.[a-zA-Z0-9]+):(\\d+)", false},
			c       = {"([a-zA-Z0-9_\\-/\\.]+\\.[a-zA-Z0-9]+):(\\d+):(\\d+)", true},
			default = {"([a-zA-Z0-9_\\-/\\.]+\\.[a-zA-Z0-9]+):(\\d+):(\\d+)", true},
		}
		local mode = patterns[arg[1]] or patterns.default
		if arg[2] == "grep" then mode = patterns.grep end
		
		local pattern,need_char = mode[1], mode[2]

		kak.execute_keys("k gl")
		kak.execute_keys("/"..pattern.."<ret>")
		
		local line,char = "%val{reg_2}","1"
		if need_char then
			char = "%val{reg_3}"
		end
		kak.evaluate_commands("edit!", "%val{reg_1}", line, char)
		kak.evaluate_commands("db! *compilation*")
	}
}
# src/tools/string.c:29:20
define-command -hidden parse-err-msg %{
    execute-keys k gl
    execute-keys /[a-zA-Z0-9_\-/]+\.([a-zA-Z0-9]+)<ret>
	lua %val{reg_1} %{
		kak.evaluate_commands("open-file-mode", arg[1])
    }
}

§

provide-module compcmd %§

#require-module luar

define-command -params 1.. \
	-docstring "compilation <cmd>: execute command and goto result output." \
	compilation %{
    try %{ evaluate-commands delete-buffer! *compilation* }
    try %{ evaluate-commands write-all }
    lua %arg{@} %{
		local cmd  = ""
		local comp = "kak_compilation_buffer"
		for _,word in ipairs(arg) do cmd = cmd..word.." " end
		kak.set_register("z", cmd)
		
		os.execute("mkfifo "..comp)
		local head = "echo \"*Compilation* start ... $(date)\" && "
		local foot = "echo \"    \" && echo \"*Compilation* end.\""
		kak.evaluate_commands("write-to-fifo", head..cmd.." && "..foot)
		
		kak.evaluate_commands("edit!", "-fifo", comp, "-scroll", "-readonly", "*compilation*")
		kak.set_option("buffer", "filetype", "compiler")
		if arg[1] == "grep" then kak.set_register("m", "grep")
		else kak.set_register("m", "else") end
    }
}

define-command -hidden -params 1.. write-to-fifo %{
	lua %arg{@} %{
    	local cmd  = ""
		local comp = "kak_compilation_buffer"
		for _,word in ipairs(arg) do cmd = cmd..word.." " end
		os.execute("({ trap - INT QUIT; eval \""..cmd.."\";} > "..comp.." 2>&1 & )")
    }
}

define-command last-compilation-cmd %{
	lua %val{reg_z} %{
    	if arg[1] == "" then return end

    	local cmd = ""
		for _,word in ipairs(arg) do cmd = cmd..word.." " end
		kak.set_register("z", "")
		kak.evaluate_commands("compilation", cmd)
    }
}

alias global c compilation
complete-command compilation file

map global user n ':last-compilation-cmd <ret>'
map global user q ':wq <ret>'
map global user b ':bn <ret>'
map global user c ':c '
map global user e ':e '

hook global KakEnd .* %{
    try %sh{ rm kak_compilation_buffer }
}

§
