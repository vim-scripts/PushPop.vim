" PushPop.vim -- pushd/popd implementation for VIM
" Author: Hari Krishna Dara <hari_vim@yahoo.com>
" Last Change:  26-Dec-2002 @ 09:28
" Created:      31-Jan-1999
" Requires: Vim-6.0, genutils.vim(1.1), multvals.vim(3.0)
" Version: 2.3.2
" Licence: This program is free software; you can redistribute it and/or
"          modify it under the terms of the GNU General Public License.
"          See http://www.gnu.org/copyleft/gpl.txt 
" Download From:
"     http://www.vim.org/script.php?script_id=129 
" Description:
"   The script provides a pushd/popd functionality for Vim taking Bash as a
"     reference. It defines new commands called Pushd, Popd (and Pud, Pod as
"     shortcuts) and Cd and Dirs. It also defines abbreviations pushd, popd, pud,
"     pod and cd (the lower case versions) to make it easy to type and get
"     used to, but if it causes any trouble for your regular command line
"     typing, just set the g:pushpopNoAbbrev variable in your .vimrc.
"   Most of the Bash pushd/popd syntax is supported.
"   The plugin integrates seamlessly with the vim features such as 'cdpath'.
"     It handles the protected command and space chars correctly as expected,
"     however, unprotected spaces are not treated as separators (which is the
"     case with 'cdpath' for the sake of backward compatibility with age old
"     vim 3.0).
"   Vim provides a "cd -" command to quickly jump back to the previous
"     directory on the lines of bash, to make it complete, the script
"     sets the g:OLDPWD variable to mimic the $OLDPWD variable of bash.
"   The Cdp command will push the directory of the current file on to the
"     stack and cd into it.
"   It provides commands to make it easy to manipulate the "cdpath" and save and
"     restore it, without needing to manually edit the vimrc, unless the
"     persistence feature of genutils.vim is disabled. The "AddDir" command
"     will allow you to add the specified directory or the current directory
"     (when no arguments are given) to "cdpath". The "RemoveDir" command can
"     be used to remove a directory by its name or index, or just the current
"     directory (when no arguments are given). To view the list of directories
"     in your "cdpath", just use the normal "set cdpath?" command or just
"     "Cdpath". In addition, the cd command accepts "-i" option to cd directly
"     into one of the directories in "cdpath". With no arguments, you will be
"     prompted with the list of directories to select from, and with an index
"     as the argument (starting from 0), you can directly cd into the
"     directory at that index.
"   It also exposes the main functions as global functions, which can be used
"     by the script writers to write scripts that can move around in the
"     directory hierarchy and finally leave the working directory as the
"     original.
" Installation:
"   Drop the script in your plugin directory to install it. Requires
"     multvals.vim and genutils.vim.
" Summary Of Features:
"   New commands:
"       Pushd, Pud, Popd, Pod, Cd, Cdp, Dirs, Cdpath,
"       AddDir, RemoveDir, -- Use -l option to specify dir name literally.
"       PPInitialize -- reinitialize the script if any settings are changed.
"   New command-line abbreviations (if not disabled):
"       pushd, popd, cd
"   New global functions:
"       PPPushd, PPPopd, PPCd, PPDirs, PPSetShowDirs
"   Settings:
"       g:pushpopShowDirs, g:pushpopNoAbbrev, g:pushpopUseGUIDialogs,
"       g:pushpopPersistCdpath
"
" Incompatibilities:
"   The Bash implementation supports the "-n" option, but it is not supported
"     here as I didn't think it is useful.
"   The "-l" option to "Dirs" doesn't have any special treatment.
"     listing. 
" TODO: {{{
"   Use delayed syncing of the top level directory, and avoid using ca.
"   How about implementing lcd also?
"   It is possible to implement cdable_vars also.
" }}}

if exists("loaded_pushpop")
  finish
endif
let loaded_pushpop = 1


" Call this any time to reconfigure the environment. This re-performs the same
"   initializations that the script does during the vim startup.
command! -nargs=0 PPInitialize :call <SID>Initialize()

" Initialize {{{
function! s:Initialize()

  "
  " Configuration options:
  "

  " Set a non-zero value to automatically executes the dirs command after every
  "   successful pushd/popd. The default is to show dirs.
  if exists("g:pushpopShowDirs")
    let s:showDirs = g:pushpopShowDirs
    unlet g:pushpopShowDirs
  elseif !exists("s:showDirs")
    let s:showDirs = 1
  endif

  if exists("g:pushpopNoAbbrev")
    let s:noAbbrev = g:pushpopNoAbbrev
    unlet g:pushpopNoAbbrev
  elseif !exists("s:noAbbrev")
    let s:noAbbrev = 0
  endif

  " Normally, we use console dialogs even in gvim, which has the advantage of
  "   having an history and expression register. But if you rather prefer GUI
  "   dialogs, then set this variable.
  if exists("g:pushpopUseGUIDialogs")
    let s:useDialogs = g:pushpopUseGUIDialogs
    unlet g:pushpopUseGUIDialogs
  elseif !exists("s:useDialogs")
    let s:useDialogs = 0
  endif

  if exists("g:pushpopPersistCdpath")
    let s:persistCdpath = g:pushpopPersistCdpath
    unlet g:pushpopPersistCdpath
  elseif !exists("s:persistCdpath")
    let s:persistCdpath = 1
  endif

  " Define the commands to conveniently access them. Use the same commands as
  " that provided by csh.
  command! -nargs=? -complete=dir Pud call PPPushd(<f-args>)
  command! -nargs=? -complete=dir Pushd call PPPushd(<f-args>)
  command! -nargs=? -complete=dir Dirs call PPDirs(<f-args>)
  command! -nargs=? -complete=dir Pod call PPPopd(<f-args>)
  command! -nargs=? -complete=dir Popd call PPPopd(<f-args>)
  command! -nargs=* -complete=dir Cd call PPCd(<f-args>)
  command! -nargs=0 -complete=dir Cdp call PPCdp()
  command! -nargs=? -complete=dir AddDir :call <SID>PPAddDir(<f-args>)
  command! -nargs=? -complete=dir RemoveDir :call <SID>PPRemoveDir(<f-args>)
  command! -nargs=? -complete=dir Cdpath :set cdpath?

  if s:noAbbrev
    silent! cuna pushd
    silent! cuna popd
    silent! cuna cd
  else
    ca pushd Pushd
    ca popd Popd
    " How nice if there is an autocommand trigger for change directory also?
    ca cd Cd
  endif

  aug PushPop
  au!
  if s:persistCdpath
    au VimEnter * call <SID>LoadSettings()
    au VimLeavePre * call <SID>SaveSettings()
  endif
  aug End
endfunction

" Defining these functions here simplifies the job of initializing dirStack.
function! s:Escape(dir)
  return substitute(a:dir, '[, ]', '\\\0', 'g')
endfunction

function! s:DeEscape(dir)
  let dir = a:dir
  let dir = substitute(dir, '\\\@<!\%(\\\\\)\\,', ',', 'g')
  let dir = substitute(dir, '\\\@<!\%(\\\\\)\\ ', ' ', 'g')
  return dir
endfunction

" Initialize the directory stack.
let s:dirStack = s:Escape(getcwd()) . ','
let g:OLDPWD = getcwd()
" Unprotected comma as separator for cdpath.
let s:COMMA_AS_SEP = '\\\@<!\%(\\\\\)*,'

call s:Initialize()
" Initialize }}}


" The front-end functions. {{{

" List out all the directories in the stack.
function! PPDirs(...)
  if a:0 == 0
    return s:DirsImpl()
  else " if a:0 == 1
    return s:DirsImpl(a:1)
  endif
endfunction


" Pushd to the current buffer's directory.
function! PPCdp()
  let path = expand("%:p")
  if ! isdirectory(path)
    let path = fnamemodify(path, ":h")
  endif
  call PPPushd(path)
endfunction


" This should only adjust the top directory in the stack.
function! PPCd(...)
  if a:0 == 0
    let dir = "" " Let vim handle no arg.
  else
    if a:0 == 1 && match(a:1, "^[-+].") == 0
      if match(a:1, '^[-+]\d\+') == -1 && a:1 != '-i'
        return s:CdUsage("bad usage.")
      endif

      let nDirs = s:NoOfCPDirs()
      if a:1 == '-i'
        if nDirs == 0
          echohl ERROR | echo "Cd: cdpath is empty." | echohl None
          return 0
        endif

        " Prompt for directory.
        let dir = s:CPPromptForDir('')
      else
        " Lookup directory by index.
        let dirIndex = strpart(a:1, 1)
        if a:1[0] == '-'
          let dirIndex = (nDirs - 1) - dirIndex
        endif
        if dirIndex < 0 || dirIndex >= nDirs
          echohl ERROR | echo "Cd: " . a:1 . ": bad cdpath index." |
	 \ echohl NONE
          return 0
        endif

        let dir = s:CPDirAt(dirIndex)
      endif
    else
      if a:0 == 1
        let dir = a:1

      " This may or may not be an error (depending on the OS), so let vim deal
      "   with it.
      else
        let __argSeparator = ' '
        exec g:makeArgumentList

        let dir = argumentList
      endif
    endif
  endif

  return s:CdImpl(dir)
endfunction


" Pushd.
function! PPPushd(...)
  if a:0 == 0
    " Exchange the first two entries.
    return s:PushdNoArgImpl()
  else " if a:0 >= 1
    " If a directory name is given, then push it on to the stack.
    if match(a:1, '^[-+]\d\+') != 0
      let dir = ''
      if a:1 == '-i'
        let nDirs = s:NoOfCPDirs()
        if nDirs == 0
          echohl ERROR | echo "Pushd: cdpath is empty." | echohl None
          return 0
        endif

        " Prompt for directory.
        let dir = s:CPPromptForDir('')
      else
        let dir = a:1
      endif
      return s:PushdImpl(dir)
    else " An index is given.
      let nDirs = s:NoOfPPDirs()
      let dirIndex = strpart(a:1, 1)
      if match(dirIndex, '\d\+') == -1
        return s:PushdUsage(a:1 . ": bad argument.")
      endif
      if a:1[0] == '-'
        let dirIndex = (nDirs - 1) - dirIndex
      endif
      if dirIndex < 0 || dirIndex >= nDirs
        echohl ERROR | echo "pushd: " . a:1 . ": bad directory stack index" |
              \ echohl NONE
        return 0
      endif

      return s:PushdIndexImpl(dirIndex)
    endif
  "else
    " Too many arguments. but sho
  endif
  return 0
endfunction


" A fron-end to s:PopdImpl()
" Prevents the stack to be emptied.
function! PPPopd(...)
  let nDirs = s:NoOfPPDirs()

  if a:0 == 0
    return s:PopdImpl()

  elseif a:0 == 1 " We expect only an index.
    let dirIndex = strpart(a:1, 1)
    if match(a:1, "^[-+]") != 0 || match(dirIndex, '\d\+') == -1
      return s:PopdUsage(a:1 . ": bad argument.")
    endif
    if a:1[0] == '-'
      let dirIndex = (nDirs - 1) - dirIndex
    endif
    if dirIndex < 0 || dirIndex >= nDirs
      echohl ERROR | echo "popd: " . a:1 . ": bad directory stack index" |
            \ echohl NONE
      return 0
    endif

    " echo "calling with one arg" a:1
    return s:PopdIndexImpl(dirIndex)
  endif
endfunction


function! PPGetShowDirs()
  return s:showDirs
endfunction


function! PPSetShowDirs(showDirs)
  let s:showDirs = a:showDirs
endfunction


function! s:PPAddDir(...)
  let newDir = ''
  if a:0 == 0
    let newDir = getcwd()
  elseif a:1 == '-l'
    if a:0 != 2
      echohl ERROR | echo "AddDir: -l option requires one argument." |
            \ echohl NONE
      return
    endif
    let newDir = a:2
  elseif a:0 != 1
    echohl ERROR | echo "AddDir: Too many arguments." | echohl NONE
    return
  else
    let newDir = fnamemodify(a:1, ':p')
  endif
  call s:CPAddDir(newDir)
endfunction


function! s:PPRemoveDir(...)
  let newDir = ''
  if a:0 == 0
    let newDir = s:RemoveDirSelectDir()
  else " if a:0 >= 1
    if a:1 == '-l'
      if a:0 != 2
        echohl ERROR | echo "RemoveDir: -l option requires one argument." |
              \ echohl NONE
        return
      endif
      let newDir = a:2
    elseif a:0 != 1
      echohl ERROR | echo "RemoveDir: Too many arguments." | echohl NONE
      return
    elseif match(a:1, '^[-+]\d\+') != 0
      let newDir = fnamemodify(a:1, ':p')
    else " An index is given.
      let nDirs = s:NoOfCPDirs()
      let dirIndex = strpart(a:1, 1)
      " Validate options.
      if match(dirIndex, '\d\+') == -1
        echohl ERROR | echo "RemoveDir: " . a:1 . ": bad argument." |
            \ echohl NONE
        return
      endif
      if a:1[0] == '-'
        let dirIndex = (nDirs - 1) - dirIndex
      endif
      if dirIndex < 0 || dirIndex >= nDirs
        echohl ERROR | echo "RemoveDir: " . a:1 . ": bad cdpath index" |
              \ echohl NONE
        return 0
      endif

      let newDir = s:CPDirAt(dirIndex)
    endif
  endif
  call s:RemoveDirImpl(newDir)
endfunction

" Front-end functions }}}


" Actual implementations {{{

function! s:CdImpl(dir)
  let success = s:ChDir(a:dir, 'cd')
  if ! success
    return 0
  else
    let nDirs = s:NoOfPPDirs()
    if nDirs == 1
      call s:PPClearDirs()
    else
      call s:PPRemoveDirAt(0)
      call s:PPInsertDirAt(getcwd(), 0)
    endif
    return 1
  endif
endfunction


function! s:DirsImpl(...)
  let dirsStr = ''
  if a:0 == 0
    let dirsStr = s:DirsStr(" ")
  else
    let opt = a:1
    let nDirs = s:NoOfPPDirs()

    " Displays the nth entry counting from the left or right (depending on +
    "   or - is used) of the list shown by dirs when invoked without options,
    "   starting with zero.
    if match(opt, '^[-+]\d\+') != -1
      let dirIndex = strpart(opt, 1)
      if match(opt, "^-") == 0
        let dirIndex = (nDirs - 1) - dirIndex
      endif
      if dirIndex < 0 || dirIndex >= nDirs
        echohl ERROR | echo "dirs: " . dirIndex . ": bad directory stack index"
              \ | echohl NONE
        return ''
      endif

      let dirsStr = s:PPDirAt(dirIndex)

      " Clears the directory stack by deleting all of the entries.
    elseif opt == "-c"
      call s:PPClearDirs()
      " Produces a longer listing; the default list-ing format uses a tilde to
      "   denote the home directory.
    elseif opt == "-l"
      " For now there is no long listing.
      let dirsStr = s:DirsStr(" ")

      " Print the directory stack with one entry per line.
    elseif opt == "-p"
      let dirsStr = s:DirsStr("\n")

      " Print the directory stack with one entry per line, prefixing each entry
      "   with its index in the stack.
    elseif opt == "-v"
      call s:StartIterator()
      let index = 0
      while s:HasNext()
        if index != 0
          let dirsStr = dirsStr . "\n"
        endif
        let dirsStr = dirsStr . " " . index . "  " . s:Next()
        let index = index + 1
      endwhile
      call s:StopIterator()

    else
      return s:DirsUsage(opt . ": bad argument.")
    endif
  endif
  if s:showDirs
    echo dirsStr
  endif
  return dirsStr
endfunction


" Push the directory on to the stack and change directory to it.
function! s:PushdImpl(dir)
  let success = s:ChDir(a:dir, 'pushd')
  if ! success
    return 0
  else
    call s:PPInsertDirAt(getcwd(), 0)
    call PPDirs()
    return 1
  endif
endfunction


" Switch between the top two dirs.
" FIXME: Can't this call the other method with index as 1? 
function! s:PushdNoArgImpl()
  let nDirs = s:NoOfPPDirs()
  if nDirs < 2
    echohl ERROR | echo "pushd: no other directory." | echohl NONE
    return 0
  endif

  let dirToCd = s:PPDirAt(1)
  let success = s:ChDir(dirToCd, 'pushd')
  if ! success
    call s:PPRemoveDirAt(1)
    return 0
  else
    call s:PPPushToFrontDirAt(1)
    call PPDirs()
    return 1
  endif
endfunction


" Cd to the directory specified by the dirIndex and make it the first dir.
function! s:PushdIndexImpl(dirIndex)
  let nDirs = s:NoOfPPDirs()
  let dirToCd = s:PPDirAt(a:dirIndex)
  let success = s:ChDir(dirToCd, 'pushd')
  if ! success
    return 0
  else
    call s:PPRotateLeftDirAt(a:dirIndex)
    call PPDirs()
    return 1
  endif
endfunction


" Pop the first directory and return it. If the first directory is popped, then
"   change to the new first directory.
"  FIXME: Can't call the other method with an index? 
function! s:PopdImpl()
  let nDirs = s:NoOfPPDirs()
  if nDirs == 1
    echohl ERROR | echo "popd: directory stack empty" | echohl NONE
    return 0
  endif

  let dirToCd = s:PPDirAt(1)
  let success = s:ChDir(dirToCd, 'popd')
  if ! success
    call s:PPRemoveDirAt(1)
    return 0
  else
    call s:PPRemoveDirAt(0)
    call PPDirs()
    return 1
  endif
endfunction


function! s:PopdIndexImpl(dirIndex)
  let nDirs = s:NoOfPPDirs()
  if nDirs == 1
    echohl ERROR | echo "popd: directory stack empty." | echohl NONE
    return 0
  endif

  call s:PPRemoveDirAt(a:dirIndex)
  call PPDirs()
  return 1
endfunction


function! s:RemoveDirSelectDir()
  let nDirs = s:NoOfCPDirs()
  if nDirs == 0
    echohl ERROR | echo "RemoveDir: cdpath is empty." | echohl NONE
    return 0
  endif

  let curDirIndex = s:CPIndexOfDir(getcwd())
  return s:CPPromptForDir(curDirIndex)
endfunction


function! s:RemoveDirIndexImpl(dirIndex)
  let nDirs = s:NoOfCPDirs()

  let selectedDir = s:CPDirAt(a:dirIndex)
  if selectedDir != ''
    return s:RemoveDirImpl(selectedDir)
  endif
endfunction


function! s:RemoveDirImpl(selectedDir)
  if ! s:CPContainsDir(a:selectedDir)
    echohl ERROR | echo "RemoveDir: . " a:selectedDir . ":" .
          \ " No such directory in cdpath." | echohl NONE
    return 0
  endif

  call s:CPRemoveDir(a:selectedDir)
  return 1
endfunction


" Returns success or failure.
function! s:ChDir(dir, for)
  let OLDPWD = getcwd()
  " echo ":cd" a:dir
  let v:errmsg = ''
  silent! exec ":cd" a:dir
  if v:errmsg != ''
    if v:errmsg == "Command failed"
      let v:errmsg = a:for . ": " . a:dir . ": No such file or diretory"
    endif
    " What is the correct hl group for this, doesn't seem to match vim's
    " message in color.
    echohl Error | echo v:errmsg | echohl None
    return 0
  endif

  " Save the previous dir in g:OLDPWD. 
  let g:OLDPWD = OLDPWD
  return 1
endfunction

" Actual implementations }}}


" Utility functions {{{

function! s:CdUsage(msg)
  echohl ERROR | echo "cd: " . a:msg | echohl None |
        \ echo "Usage: Cd [dir | -i | +<index> | -<index>]"
  return 0
endfunction


function! s:PushdUsage(msg)
  echohl ERROR | echo "pushd: " . a:msg | echohl None |
        \ echo "Usage: pushd [dir | +<index> | -<index>]"
  return 0
endfunction


function! s:PopdUsage(msg)
  echohl ERROR | echo "popd: " . a:msg | echohl None |
        \ echo "Usage: popd [+<index> | -<index>]"
  return 0
endfunction


function! s:DirsUsage(msg)
  echohl ERROR | echo "dirs: " . a:msg | echohl None |
        \ echo "Usage: dirs [-c | -l | -p | -v | +<index> | -<index>]"
  return ''
endfunction


" Count the number of directories in the stack.
function! s:NoOfPPDirs()
  return MvNumberOfElements(s:dirStack, s:COMMA_AS_SEP, ',')
endfunction


function! s:PPDirAt(dirIndex)
  return s:DeEscape(MvElementAt(s:dirStack, s:COMMA_AS_SEP, a:dirIndex, ','))
endfunction


function! s:PPClearDirs()
  let s:dirStack = s:Escape(getcwd()) . ','
endfunction


function! s:PPRemoveDirAt(dirIndex)
  let s:dirStack = MvRemoveElementAt(s:dirStack, s:COMMA_AS_SEP, a:dirIndex,
	\ ',')
endfunction


function! s:PPInsertDirAt(dir, dirIndex)
  let s:dirStack = MvInsertElementAt(s:dirStack, s:COMMA_AS_SEP,
        \ s:Escape(a:dir), a:dirIndex, ',')
endfunction


function! s:PPPushToFrontDirAt(dirIndex)
  let s:dirStack = MvPushToFrontElementAt(s:dirStack, s:COMMA_AS_SEP,
	\ a:dirIndex, ',')
endfunction


function! s:PPRotateLeftDirAt(dirIndex)
  let s:dirStack = MvRotateLeftAt(s:dirStack, s:COMMA_AS_SEP, a:dirIndex, ',')
endfunction


function! s:DirsStr(sep)
  let dirsStr = substitute(s:dirStack, ',$', '', '')
  return s:DeEscape(substitute(dirsStr, s:COMMA_AS_SEP, a:sep, "g"))
endfunction


function! s:StartIterator()
  call MvIterCreate(s:dirStack, s:COMMA_AS_SEP, "PushPop", ',')
endfunction


function! s:HasNext()
  return MvIterHasNext("PushPop")
endfunction


function! s:Next()
    return MvIterNext("PushPop")
endfunction


function! s:StopIterator()
  call MvIterDestroy("PushPop")
endfunction


function! s:NoOfCPDirs()
  return MvNumberOfElements(&cdpath, s:COMMA_AS_SEP, ',')
endfunction


function! s:CPDirAt(dirIndex)
  return s:DeEscape(MvElementAt(&cdpath, s:COMMA_AS_SEP, a:dirIndex, ','))
endfunction


function! s:CPIndexOfDir(dir)
  return MvIndexOfElement(&cdpath, s:COMMA_AS_SEP, s:Escape(a:dir), ',')
endfunction


function! s:CPRemoveDirAt(dirIndex)
  let &cdpath = MvRemoveElementAt(&cdpath, s:COMMA_AS_SEP, a:dirIndex,
	\ ',')
endfunction


function! s:CPInsertDirAt(dir, dirIndex)
  let &cdpath = MvInsertElementAt(&cdpath, s:COMMA_AS_SEP,
        \ s:Escape(a:dir), a:dirIndex, ',')
endfunction


function! s:CPRemoveDir(dir)
  let &cdpath = MvRemoveElement(&cdpath, s:COMMA_AS_SEP, s:Escape(a:dir), ',')
endfunction


function! s:CPContainsDir(dir)
  return MvContainsElement(&cdpath, s:COMMA_AS_SEP, s:Escape(a:dir), ',')
endfunction


function! s:CPPromptForDir(default)
  return s:DeEscape(MvPromptForElement(&cdpath, s:COMMA_AS_SEP, a:default,
        \ "Select the directory: ", -1, s:useDialogs, ','))
endfunction


function! s:CPAddDir(dir)
  let &cdpath = MvAddElement(&cdpath, s:COMMA_AS_SEP, s:Escape(a:dir), ',')
endfunction


function! s:LoadSettings()
  let &cdpath = GetPersistentVar("PushPop", "cdpath", &cdpath)
  " Just to simplify the handling of cdpath.
  let &cdpath = substitute(&cdpath, ',,', ',.,', 'g')
  let &cdpath = substitute(&cdpath, '^,', '', '')
  let &cdpath = substitute(&cdpath, ',$', '', '')
endfunction


function! s:SaveSettings()
  call PutPersistentVar("PushPop", "cdpath", &cdpath)
  unlet g:OLDPWD " Avoid saving this, there is no meaning for this next time.
endfunction


" FIXME: Need a test function.
"function! TestPushPop()
"endfunction
 
" Utility functions }}}

" vim6:fdm=marker
