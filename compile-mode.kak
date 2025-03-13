
provide-module compilation %{

declare-option str last_command        ""
declare-option str compilation_env     ""
declare-option int compilation_env_set 0

define-command -params .. -file-completion \
    -docstring %{
        compile <shell command>: run shell command and see result in compilation mode.
    } compile %{
     write-all

     set-option global last_command "%arg{@}"
     evaluate-commands %sh{
     output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-compilation.XXXXXXXX)/fifo
     mkfifo ${output}
     ( { trap - INT QUIT; eval "echo \"*compilation begin*  at: $(date)\""

     if [ "${kak_opt_compilation_env_set}" -ne 0 ]; then
        echo "ENV: ${kak_opt_compilation_env}"
        eval "${kak_opt_compilation_env}"
     fi;

     echo "CMD: $@\n"
     eval "$@"
     
     exit_code=$?
     if [ $exit_code -ne 0 ]; then
        echo "\n*compilation failed* with return code: $exit_code"
     else
        echo "\n*compilation end*    at: $(date)"
     fi; } > ${output} 2>&1 & ) > /dev/null 2>&1 < /dev/null

     printf %s\\n "evaluate-commands -try-client '$kak_opt_toolsclient' %{
               edit! -fifo ${output} -scroll *compilation*
               set-option buffer filetype compilation
               hook -always -once buffer BufCloseFifo .* %{
                    nop %sh{ rm -r $(dirname ${output}) }
               }
           }"
    }
}

alias global c compile
map global user c :c<space>
map global user n :c<space>%opt{last_command}<ret>
map global user s :set-compilation-env<space>

define-command -params .. -file-completion set-compilation-env %{
    set-option global compilation_env_set 1
    set-option global compilation_env "%arg{@}"
}

define-command -hidden get-file-extension %{
    try %{
        execute-keys xs ([\w\d_\-/]+\.[\w\d]+):(\d+):(\d+) <ret>
        edit %reg{1} %reg{2} %reg{3} 
    } catch %{ try %{
        execute-keys xs ([\w\d_\-/]+\.[\w\d]+):(\d+) <ret>
        edit %reg{1} %reg{2}
    } catch %{ try %{
        execute-keys xs ([\w\d_\-/]+\.[\w\d]+)\((\d+),(\d+)\) <ret>
        edit %reg{1} %reg{2} %reg{3} 
    } catch %{ try %{
        execute-keys xs ([\w\d_\-/]+\.[\w\d]+)\((\d+):(\d+)\) <ret>
        edit %reg{1} %reg{2} %reg{3} 
    } catch %{ try %{
        execute-keys xs ([\w\d_\-/]+\.[\w\d]+) <ret>
        edit %reg{1}
    } catch %{
        try %{
            execute-keys gg / [\w\d_\-/]+\.[\w\d]+:<ret>
            evaluate-commands get-file-extension
        } catch %{ try %{
            execute-keys gg / [\w\d_\-/]+\.[\w\d]+\(<ret>
            evaluate-commands get-file-extension
        } catch %{ delete-buffer! }}
    }}}}}
}

add-highlighter shared/compilation group
add-highlighter shared/compilation/ regex "\*compilation begin\*"  0:default+b
add-highlighter shared/compilation/ regex "\*compilation end\*"    0:default+b
add-highlighter shared/compilation/ regex "\*compilation failed\*" 0:red+b

add-highlighter shared/compilation/ regex "ERROR:" 0:red+b
add-highlighter shared/compilation/ regex "Error:" 0:red+b
add-highlighter shared/compilation/ regex "error:" 0:red+b

add-highlighter shared/compilation/ regex "WARNIG:" 0:yellow+b
add-highlighter shared/compilation/ regex "Warnig:" 0:yellow+b
add-highlighter shared/compilation/ regex "warnig:" 0:yellow+b

add-highlighter shared/compilation/ regex "NOTE" 0:default+b
add-highlighter shared/compilation/ regex "Note" 0:default+b
add-highlighter shared/compilation/ regex "note" 0:default+b

add-highlighter shared/compilation/ regex "[\w\d_\-/]+\.[\w\d]+" 0:keyword

hook -group compilation-highlight global WinSetOption filetype=compilation %{
    add-highlighter window/compilation ref compilation
    hook window NormalKey <ret> %{ get-file-extension }
    hook -once -always window WinSetOption filetype=.* %{
        remove-highlighter window/compilation
    }
}

}
