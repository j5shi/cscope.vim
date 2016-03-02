" File: cscope.vim
" Author: Jia Shi <j5shi.vip@gmail.com>
" Last Modified: 2015-09-18 21:30:09
" Copyright: Copyright (C) 2015 Jia Shi 
" License: The MIT License
"
let s:cscope_vim_db_dir                    = substitute($HOME,'\\','/','g')."/.cscope.vim"
let s:cscope_vim_db_index_file             = s:cscope_vim_db_dir.'/index'
let s:cscope_vim_db_entry_idx_project_root = 0
let s:cscope_vim_db_entry_idx_id           = 1
let s:cscope_vim_db_entry_idx_loadtimes    = 2
let s:cscope_vim_db_entry_idx_dirty        = 3
let s:cscope_vim_db_entry_idx_depedency    = 4
let s:cscope_vim_db_entry_len              = 5
let s:cscope_vim_db_entry_key_id           = 'id'
let s:cscope_vim_db_entry_key_loadtimes    = 'loadtimes'
let s:cscope_vim_db_entry_key_dirty        = 'dirty'
let s:cscope_vim_db_entry_key_depedency    = 'depedency'
let s:cscope_vim_working_project_root      = ""

"*********************************************************
" @param query_mode <char>: cscope query mode, e.g. 's', 'g'...
"
" @param query_str   <str>: query string.
"
" @param va_list[1] <enum>: 'horizontal' search result window
"                                        will be split horizontally
"                           'vertical'   search result window
"                                        will be split virtically
"*********************************************************
function! CscopeFind(query_mode, query_str, ...)
    if cscope_connection() == 0 && g:cscope_auto_connect_db == 1
        call <SID>cscope_vim_connect_db()
    endif

    if cscope_connection() == 0
        echohl WarningMsg | echo 'No cscope database is connected!' | echohl None
        return
    endif

    try
        if a:0 == 0 
            exe 'cs f '.a:query_mode.' '.a:query_str
        elseif a:0 >= 1 && a:1 == 'horizontal'
            exe 'scs f '.a:query_mode.' '.a:query_str
        elseif a:0 >= 1 && a:1 == 'vertical'
            exe 'vert scs f '.a:query_mode.' '.a:query_str
        endif

        if g:cscope_vim_open_location_list == 1
            cw
            call matchadd("Search", a:query_str)
        endif
    catch
        echohl WarningMsg | echo 'Can not find '.a:query_str.' with query mode as '.a:query_mode.'.' | echohl None
    endtry
endfunction

"*********************************************************
" @parm query_str   <str>: query string.
"*********************************************************
function! CscopeFindInteractive(query_str)
    if cscope_connection() == 0 && g:cscope_auto_connect_db == 1
        call <SID>cscope_vim_connect_db()
    endif

    if cscope_connection() == 0
        echohl WarningMsg | echo 'No cscope database is connected!' | echohl None
        return
    endif

    call inputsave()

    let l:query = input("\nChoose a query mode for '".a:query_str."'(:help cscope-find)\n  
                         \c: functions calling this function\n  
                         \d: functions called by this function\n  
                         \e: this egrep pattern\n  
                         \f: this file\n  
                         \g: this definition\n  
                         \i: files #including this file\n  
                         \s: this C symbol\n  
                         \t: this text string\n\n  
                         \Or use <querytype><pattern> to query instead\n  
                         \e.g. `smain` to query a C symbol named 'main'.\n> ")

    call inputrestore()

    if len(l:query) > 1
        call CscopeFind(l:query[0], l:query[1:])
    elseif len(l:query) > 0
        call CscopeFind(l:query, a:query_str)
    endif
endfunction

function! s:cscope_vim_load_index()
    " s:dbs = { 'project_root1': {'id'       : '',
    "                             'loadtimes': '',
    "                             'dirty'    : 0|1,
    "                             'depedency': '...;...'},
    "           'project_root1': {'id'       : '',         
    "                             'loadtimes': '',         
    "                             'dirty'    : 0|1,        
    "                             'depedency': '...;...'}, 
    "                   ...
    "         }
    let s:dbs = {}
    
    if !isdirectory(s:cscope_vim_db_dir)
        call mkdir(s:cscope_vim_db_dir)
    elseif !filereadable(s:cscope_vim_db_index_file)
        call <SID>cscope_vim_remove_all_db_and_index_files()
    else
        for l:line in readfile(s:cscope_vim_db_index_file)
            let l:db_entry = split(l:line, '|')
        
            " In case the index file is corrupted, delete all the
            " project file indexes and dbs to start over.
            if len(l:db_entry) != s:cscope_vim_db_entry_len
                call <SID>cscope_vim_remove_all_db_and_index_files()
            else
                let l:db_file_name    = s:cscope_vim_db_dir.'/'.l:db_entry[s:cscope_vim_db_entry_idx_id].'.db'
                let l:db_in_file_name = s:cscope_vim_db_dir.'/'.l:db_entry[s:cscope_vim_db_entry_idx_id].'.db.in'
                let l:db_po_file_name = s:cscope_vim_db_dir.'/'.l:db_entry[s:cscope_vim_db_entry_idx_id].'.db.po'
                let l:db_file_list    = s:cscope_vim_db_dir.'/'.l:db_entry[s:cscope_vim_db_entry_idx_id].'.files'
        
                " If the project root got deleted, renamed, 
                " moved, then the db and project file list 
                " will be invalid, so, delete them.
                if !isdirectory(l:db_entry[s:cscope_vim_db_entry_idx_project_root])
                    call delete(l:db_file_name)
                    call delete(l:db_in_file_name)
                    call delete(l:db_po_file_name)
                    call delete(l:db_file_list)
                else
                    let s:dbs[l:db_entry[s:cscope_vim_db_entry_idx_project_root]]                                      = {}
                    let s:dbs[l:db_entry[s:cscope_vim_db_entry_idx_project_root]][s:cscope_vim_db_entry_key_id]        = l:db_entry[s:cscope_vim_db_entry_idx_id]
                    let s:dbs[l:db_entry[s:cscope_vim_db_entry_idx_project_root]][s:cscope_vim_db_entry_key_loadtimes] = l:db_entry[s:cscope_vim_db_entry_idx_loadtimes]
                    let s:dbs[l:db_entry[s:cscope_vim_db_entry_idx_project_root]][s:cscope_vim_db_entry_key_dirty]     = l:db_entry[s:cscope_vim_db_entry_idx_dirty]
                    let s:dbs[l:db_entry[s:cscope_vim_db_entry_idx_project_root]][s:cscope_vim_db_entry_key_depedency] = l:db_entry[s:cscope_vim_db_entry_idx_depedency]
                endif
            endif
        endfor

        call <SID>cscope_vim_flush_index()
    endif
endfunction

function! s:cscope_vim_flush_index()
    let l:lines = []

    for l:project_root in keys(s:dbs)
        call add(l:lines, 
                \l:project_root.'|'.
                \s:dbs[l:project_root][s:cscope_vim_db_entry_key_id].'|'.
                \s:dbs[l:project_root][s:cscope_vim_db_entry_key_loadtimes].'|'.
                \s:dbs[l:project_root][s:cscope_vim_db_entry_key_dirty].'|'.
                \s:dbs[l:project_root][s:cscope_vim_db_entry_key_depedency].'|')
    endfor

    call writefile(l:lines, s:cscope_vim_db_index_file)
endfunction

function! s:cscope_vim_list_files(root_dir)
    let l:sub_dir_list = []
    let l:file_list    = []
    let l:cwd          = a:root_dir
    let l:status       = &l:statusline

    while l:cwd != ''
        let l:items = split(globpath(l:cwd, "*"), "\n")

        for l:item in l:items
            if getftype(l:item) == 'dir'
                call add(l:sub_dir_list, l:item)
            elseif getftype(l:item) != 'file'
                continue
            elseif l:item !~? g:cscope_interested_files
                continue
            else
                if stridx(l:item, ' ') != -1
                    let l:item = '"'.l:item.'"'
                endif

                call add(l:file_list, l:item)
            endif
        endfor

        let l:cwd = len(l:sub_dir_list) ? remove(l:sub_dir_list, 0) : ''

        sleep 1m | let &l:statusline = 'Found '.len(l:file_list).' files in '.l:cwd | redrawstatus
    endwhile

    " restore the status line
    sleep 1m | let &l:statusline = l:status | redrawstatus

    return l:file_list
endfunction

function! s:cscope_vim_remove_all_db_and_index_files()
    for l:file in split(globpath(s:cscope_vim_db_dir, "*"), "\n")
        call delete(l:file)
    endfor
endfunction

function! s:cscope_vim_ask_for_project_root(current_path)
    echohl WarningMsg | echo "Please input a project root path to create a cscope database (<C-Break> to quit)." | echohl None

    while 1
        let l:project_root = input("", a:current_path, 'dir')

        if !isdirectory(l:project_root)
            echohl WarningMsg | echo "\nPlease input a valid project root path (<C-Break> to quit)." | echohl None
        elseif (len(l:project_root) < 2 || (l:project_root[0] != '/' && l:project_root[1] != ':'))
            echohl WarningMsg | echo "\nPlease input an absolute project root path (<C-Break> to quit)." | echohl None
        else
            break
        endif
    endwhile

    return <SID>cscope_vim_unify_path(l:project_root)
endfunction

function! s:cscope_vim_ask_for_dependent_project_root(current_path)
    echohl WarningMsg | echo "\nPlease input dependent project root paths, if any (<C-Break> to quit)." | echohl None

    let l:dependent_project_root = ""

    while 1
        let l:dependent_project_root_tmp = input("", "", 'dir')

        if l:dependent_project_root_tmp == ""
            break
        elseif !isdirectory(l:dependent_project_root_tmp)
            echohl WarningMsg | echo "\nPlease input a valid dependent project root path (<C-Break> to quit)." | echohl None
        elseif (len(l:dependent_project_root_tmp) < 2 || (l:dependent_project_root_tmp[0] != '/' && l:dependent_project_root_tmp[1] != ':'))
            echohl WarningMsg | echo "\nPlease input an absolute dependent project root path (<C-Break> to quit)." | echohl None
        else
            let l:dependent_project_root .= ";".l:dependent_project_root_tmp
        endif
    endwhile

    return <SID>cscope_vim_unify_path(l:dependent_project_root)
endfunction

function! s:cscope_vim_get_project_root(current_path)
    let l:current_path_unified    = <SID>cscope_vim_unify_path(a:current_path)
    let l:project_root_best_match = ""

    for l:project_root in keys(s:dbs)
        if stridx(l:current_path_unified, l:project_root) == 0 && len(l:project_root) > len(l:project_root_best_match)
            let l:project_root_best_match = l:project_root
        endif
    endfor
    
    if l:project_root_best_match != ""
        return l:project_root_best_match
    else
        if s:cscope_vim_working_project_root != ""
            return s:cscope_vim_working_project_root
        endif
    endif
endfunction

function! s:cscope_vim_init_db(current_path)
    let l:project_root = <SID>cscope_vim_ask_for_project_root(a:current_path)
    let l:dependent_project_root = <SID>cscope_vim_ask_for_dependent_project_root(a:current_path)
    
    let s:dbs[l:project_root]                                      = {}
    let s:dbs[l:project_root][s:cscope_vim_db_entry_key_id]        = localtime()
    let s:dbs[l:project_root][s:cscope_vim_db_entry_key_loadtimes] = 0
    let s:dbs[l:project_root][s:cscope_vim_db_entry_key_dirty]     = 0
    let s:dbs[l:project_root][s:cscope_vim_db_entry_key_depedency] = g:cscope_common_project_root.";".l:dependent_project_root

    call <SID>cscope_vim_flush_index()

    return l:project_root
endfunction

" Delete any files related to the db to be deleted.
"
" @param clear_which         <enum>:  -1   all database
"                                      0   the current database
function! s:cscope_vim_clear_db(clear_which)
    cs kill -1
    
    if a:clear_which == -1
        let s:dbs = {}
        call <SID>cscope_vim_remove_all_db_and_index_files()
        call <SID>cscope_vim_flush_index()
    elseif a:clear_which == 0
        let l:current_path = <SID>cscope_vim_unify_path(expand('%:p:h'))
        let l:project_root = <SID>cscope_vim_get_project_root(l:current_path)

        if l:project_root != ""
            let l:current_db_related_files = split(globpath(s:cscope_vim_db_dir, 
                                                           \s:dbs[l:project_root][s:cscope_vim_db_entry_key_id]."*"), 
                                                  \"\n")

            for l:file in l:current_db_related_files
                call delete(l:file)
            endfor

            " unlet s:dbs[l:project_root]

            call <SID>cscope_vim_flush_index()
        endif
    endif
endfunction

function! s:cscope_vim_list_db()
    let l:project_roots = keys(s:dbs)

    if len(l:project_roots) == 0
        echo "You have no cscope db now."
    else
        let l:db_info = [' ID           LOAD_TIMES       PATH']

        for l:project_root in l:project_roots
            let l:id         = s:dbs[l:project_root][s:cscope_vim_db_entry_key_id]
            let l:load_times = s:dbs[l:project_root][s:cscope_vim_db_entry_key_loadtimes]

            if cscope_connection(2, s:cscope_vim_db_dir.'/'.id.'.db') == 1
                let l:disply_info = printf("*%d   %10d       %s", l:id, l:load_times, l:project_root)
            else
                let l:disply_info = printf(" %d   %10d       %s", l:id, l:load_times, l:project_root)
            endif

            call add(l:db_info, l:disply_info)
        endfor

        echo join(l:db_info, "\n")
    endif
endfunction

function! s:cscope_vim_build_db(project_root, force_update_file_list)
    let l:id                 = s:dbs[a:project_root][s:cscope_vim_db_entry_key_id]
    let l:dependent_projects = split(s:dbs[a:project_root][s:cscope_vim_db_entry_key_depedency], ';')
    let l:cscope_files       = s:cscope_vim_db_dir."/".id.".files"
    let l:cscope_db          = s:cscope_vim_db_dir.'/'.id.'.db'

    if a:force_update_file_list
        let l:files = []

        for l:root_dir in [a:project_root] + l:dependent_projects
            let l:files += <SID>cscope_vim_list_files(l:root_dir)
        endfor

        call writefile(l:files, l:cscope_files)
    endif

    " build cscope database, must build in the root path otherwise 
    " there might be errors in generating database, e.g. invalid path 
    " for symbols.
    exec 'chdir '.a:project_root

    exec 'cs kill '.l:cscope_db

    " save commands to x resiger for debugging and building result checking
    redir @x

    if g:cscope_sort_tool_dir != ""
        exec 'chdir '.g:cscope_sort_tool_dir
        exec 'silent !'.g:cscope_cmd.' -q -b -i '.l:cscope_files.' -f '.l:cscope_db
    else
        exec 'silent !'.g:cscope_cmd.' -b -i '.l:cscope_files.' -f '.l:cscope_db
    endif

    redir END

    " check build result and add database
    if @x =~ "\nCommand terminated\n"
        echohl WarningMsg | echo "Failed to create cscope database for ".a:project_root.", please check if " | echohl None
        let s:dbs[a:project_root][s:cscope_vim_db_entry_key_dirty] = 1
    else
        let s:dbs[a:project_root][s:cscope_vim_db_entry_key_dirty] = 0
    endif

    call <SID>cscope_vim_flush_index()
endfunction

function! s:cscope_vim_rebuild_current_db()
    call <SID>cscope_vim_clear_db(0)

    let l:current_path = <SID>cscope_vim_unify_path(expand('%:p:h'))
    let l:project_root = <SID>cscope_vim_init_db(l:current_path)

    if l:project_root != ""
        if g:cscope_update_db_asynchronously == 1
            echohl WarningMsg | echo "Asynchronous updating is not supported yet!" | echohl None
        else
            call <SID>cscope_vim_build_db(l:project_root, 1)
            call <SID>cscope_vim_connect_db()
        endif
    endif
endfunction

function! s:cscope_vim_update_current_db(force_update_file_list)
    let l:current_path = <SID>cscope_vim_unify_path(expand('%:p:h'))
    let l:project_root = <SID>cscope_vim_get_project_root(l:current_path)

    if l:project_root == ""
        echohl WarningMsg | echo "Project not found, nothing to update!" | echohl None
    else
        if g:cscope_update_db_asynchronously == 1
            echohl WarningMsg | echo "Asynchronous updating is not supported yet!" | echohl None
        else
            call <SID>cscope_vim_build_db(l:project_root, a:force_update_file_list)
            call <SID>cscope_vim_connect_db()
        endif
    endif
endfunction

" 1) kill all the cscope db connections, if any.
" 2) if the current file is not a part of a project, stop.
" 3) if the current file is a part of a project:
"    3.1) if db not exists, warning, stop
"    3.2) if db exists, connect to it, stop
" 4) set current working project
function! s:cscope_vim_connect_db()
    " 1) kill all the cscope db connections, if any.
    cs kill -1
    
    let l:current_path = <SID>cscope_vim_unify_path(expand('%:p:h'))
    let l:project_root = <SID>cscope_vim_get_project_root(l:current_path)

    " 2) if the current file is not a part of any project, stop.
    if l:project_root == ""
        echohl WarningMsg | echo "Project not found, please create one first!" | echohl None
        return
    endif

    " 3) if the current file is a part of a project:
    let l:db_file_name = s:cscope_vim_db_dir.'/'.s:dbs[l:project_root][s:cscope_vim_db_entry_key_id].'.db'
    let l:db_file_list = s:cscope_vim_db_dir.'/'.s:dbs[l:project_root][s:cscope_vim_db_entry_key_id].'.files'
    let l:db_prepend   = l:project_root

    " 3.1) if db not exists, warning, stop
    if !filereadable(l:db_file_name)
        echohl WarningMsg | echo "Project found but cscope database is missing, please create one first!" | echohl None
        return
    endif
    
    " 3.2) if db file list not exists, warning, stop
    if !filereadable(l:db_file_list)
        echohl WarningMsg | echo "Project found but cscope database file list is missing, please re-create the db!" | echohl None
        return
    endif

    " 3.3) if db exists, connect to it, stop
    if g:cscope_search_case_insensitive == 1
        exe 'cs add '.l:db_file_name.' '.l:db_prepend.' -C'
        echo 'cscope db '.l:db_file_name.' added, working in case-insensitive mode.'
    else
        exe 'cs add '.l:db_file_name.' '.l:db_prepend
        echo 'cscope db '.l:db_file_name.' added, working in case-sensitive mode.'
    endif

    " 4) set current working project
    let s:cscope_vim_working_project_root = l:project_root
    let s:dbs[l:project_root][s:cscope_vim_db_entry_key_loadtimes] += 1

    call <SID>cscope_vim_flush_index()
endfunction

function! s:cscope_vim_unify_path(path_non_unified)
    let l:path_unified = substitute(a:path_non_unified, '\\', '/', 'g')
    let l:path_unified = substitute(l:path_unified, '/\+$', '', '')
    let l:path_unified = substitute(l:path_unified, "\/\\s*$", '', 'g')

    return tolower(l:path_unified)
endfunction

if !exists('g:cscope_auto_connect_db')
    let g:cscope_auto_connect_db = 0
endif

if !exists('g:cscope_vim_open_location_list')
    let g:cscope_vim_open_location_list = 1
endif

if !exists('g:cscope_search_case_insensitive')
    let g:cscope_search_case_insensitive = 0
endif

if !exists('g:cscope_update_db_asynchronously')
    let g:cscope_update_db_asynchronously = 0
endif

if !exists('g:cscope_cmd')
    if executable('cscope')
        let g:cscope_cmd = 'cscope'
    else
        echo 'cscope: command not found'
        finish
    endif
endif

if !exists('g:cscope_sort_tool_dir')
    let g:cscope_sort_tool_dir = ''
endif


if !exists('g:cscope_interested_files')
    let g:cscope_interested_files = '\.c$\|\.cpp$\|\.h$\|\.hpp' 
endif

if !exists('g:cscope_common_project_root')
    let g:cscope_common_project_root = ""
else
    let g:cscope_common_project_root = <sid>cscope_vim_unify_path(g:cscope_common_project_root)
endif

command! -nargs=0 CscopeConnectDb                  call <SID>cscope_vim_connect_db()
command! -nargs=0 CscopeClearAllDb                 call <SID>cscope_vim_clear_db(-1)
command! -nargs=0 CscopeClearCurrentDb             call <SID>cscope_vim_clear_db(0)
command! -nargs=0 CscopeList                       call <SID>cscope_vim_list_db()
command! -nargs=0 CscopeRebuildDb                  call <SID>cscope_vim_rebuild_current_db()
command! -nargs=0 CscopeUpdateDb                   call <SID>cscope_vim_update_current_db(0)
command! -nargs=0 CscopeUpdateDbAndFilelist        call <SID>cscope_vim_update_current_db(1)

set cscopequickfix=s-,g-,d-,c-,t-,e-,f-,i-
call <sid>cscope_vim_load_index()
