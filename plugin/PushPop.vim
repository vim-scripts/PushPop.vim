" PushPop.vim -- pushd/popd implementation for VIM
" Author: Hari Krishna Dara <hari_vim@yahoo.com>
" Last Change:  13-Aug-2002 @ 23:33
" Created:      31-Jan-1999
" Requires: Vim-6.0, genutils.vim(1.1), multvals.vim(2.1.1)
" Version: 2.1.1
" Description:
"   The script provides a pushd/popd functionality for Vim taking Bash as a
"     reference. It defines new commands called Pushd, Popd (and Pud, Pod as
"     shortcuts), Cd and Dirs. It also defines abbreviations pushd, popd, pud,
"     pod cd and dirs (the lower case versions) to make it easy to type and get
"     used to, but if it causes any trouble for your regular command line
"     typing, just set the g:pushpopNoAbbrev variable in your .vimrc.
"   Most of the Bash pushd/popd syntax is supported.
"   The plugin integrates seamlessly with the vim features such as 'cdpath'.
"   Vim provides a "cd -" command to quickly jump back to the previous
"   directory on the lines of bash, but just to make it complete, the script
"   sets the g:OLDPWD variable to mimic the $OLDPWD variable of bash.
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
"       AddDir, RemoveDir,
"       PPInitialize -- reinitialize the script if any settings are changed.
"   New command-line abbreviations (if not disabled):
"       pushd, popd, cd, dirs
"   New global functions:
"       PPPushd, PPPopd, PPCd, PPDirs, PPSetShowDirs
"   Settings:
"       g:pushpopDirSep, g:pushpopShowDirs, g:pushpopNoAbbrev,
"       g:pushpopUseGUIDialogs
"
" Incompatibilities:
"   The Bash implementation supports the "-n" option, but it is not supported
"     here as I didn't think it is useful.
"   The "-l" option to "dirs" doesn't have any special treatment.
"     listing. 
" TODO: {{{
"   Use delayed syncing of the top level directory, and avoid doing a ca.
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

function! s:Initialize()

"
" Configuration options:
"

" Configure the separator string for separating the directory stack.
if exists("g:pushpopDirSep")
  let s:dirSep = g:pushpopDirSep
  unlet g:pushpopDirSep
elseif !exists("s:dirSep")
  let s:dirSep = ';'
endif

" Set a non-zero value to automatically executes the dirs command after every
"   successful pushd/popd. The default is to show dirs.
if exists("g:pushpopShowDirs")
  let s:showDirs = g:pushpopShowDirs
  unlet g:pushpopShowDirs
elseif !exists("s:showDirs")
  let s:showDirs = 1
endif

" Define the commands to conveniently access them. Use the same commands as
" that provided by csh.
command! -nargs=? -complete=dir Pud call PPPushd(<f-args>)
command! -nargs=? -complete=dir Pushd call PPPushd(<f-args>)
command! -nargs=? -complete=dir Dirs call PPDirs(<f-args>)
command! -nargs=? -complete=dir Pod call PPPopd(<f-args>)
command! -nargs=? -complete=dir Popd call PPPopd(<f-args>)
command! -nargs=* -complete=dir Cd call PPCd(<f-args>)
command! -nargs=? -complete=dir Cdp call PPPushd(expand("%:p:h"))
command! -nargs=? -complete=dir AddDir :call <SID>PPAddDir(<f-args>)
command! -nargs=? -complete=dir RemoveDir :call <SID>PPRemoveDir(<f-args>)
command! -nargs=? -complete=dir Cdpath :set cdpath?

if exists("g:pushpopNoAbbrev")
  let s:noAbbrev = g:pushpopNoAbbrev
  unlet g:pushpopNoAbbrev
elseif !exists("s:noAbbrev")
  let s:noAbbrev = 0
endif

if s:noAbbrev
  silent! cuna pushd
  silent! cuna popd
  silent! cuna dir
  silent! cuna cd
else
  ca pushd Pushd
  ca popd Popd
  ca dirs Dirs
  " How nice if there is an autocommand trigger for change directory also?
  ca cd Cd
endif

" Initialize the directory stack.
let s:dirStack = getcwd()
let g:OLDPWD = getcwd()

" Normally, we use consolve dialogs even in gvim, which has the advantage of
"   having an history and expression register. But if you rather prefer GUI
"   dialogs, then set this variable.
if exists("g:pushpopUseGUIDialogs")
  let s:useDialogs = g:pushpopUseGUIDialogs
  unlet g:pushpopUseGUIDialogs
elseif !exists("s:useDialogs")
  let s:useDialogs = 0
endif

aug PushPop
au!
au VimEnter * call <SID>LoadSettings()
au VimLeavePre * call <SID>SaveSettings()
aug End

endfunction " s:Initialize

call s:Initialize()

"
" The front-end functions.
"

" List out all the directories in the stack.
function! PPDirs(...)
  if a:0 == 0
    return s:DirsImpl()
  else " if a:0 == 1
    return s:DirsImpl(a:1)
  endif
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

      let nDirs = MvNumberOfElements(&cdpath, ',')
      if a:1 == '-i'
	if nDirs == 0
	  echohl ERROR | echo "Cd: cdpath is empty." | echohl None
	  return 0
	endif

	" Prompt for directory.
	let dir = MvPromptForElement(&cdpath, ',', '',
	      \ "Select the directory: ", -1, s:useDialogs)
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

	let dir = MvElementAt(&cdpath, ',', dirIndex)
      endif
    else
      if a:0 == 1
	let dir = a:1

      else " This may or may not be an error, so let vim deal with it.
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

  else " if a:0 == 1
    " If a directory name is given, then push it on to the stack.
    if match(a:1, "^[-+]") != 0
      return s:PushdImpl(a:1)

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
  else
    let newDir = a:1
  endif
  let &cdpath = MvAddElement(&cdpath, ',', newDir)
endfunction


function! s:PPRemoveDir(...)
  if a:0 == 0
    call s:RemoveDirPromptImpl()

  else " if a:0 == 1
    if match(a:1, "^[-+]") != 0
      call s:RemoveDirImpl(a:1)

    else " An index is given.
      let nDirs = MvNumberOfElements(&cdpath, ',')
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
      if dirIndex < 0 dirIndex >= nDirs
	echohl ERROR | echo "RemoveDir: " . a:1 . ": bad cdpath index" |
	      \ echohl NONE
	return 0
      endif

      call s:RemoveDirIndexImpl(dirIndex)
    endif
  endif
endfunction


"
" Helper functions to hide datastructures.
"

function! s:CdImpl(dir)
  let success = s:ChDir(a:dir, 'cd')
  if ! success
    return 0
  else
    let nDirs = s:NoOfPPDirs()
    if nDirs == 1
      let s:dirStack = getcwd()
    else
      call s:RemoveDirAt(0)
      call s:InsertDirAt(getcwd(), 0)
    endif
    return 1
  endif
endfunction


function! s:DirsImpl(...)
  let dirsStr = ''
  if a:0 == 0
    let dirsStr = substitute(s:dirStack, s:dirSep, " ", "g")
  else
    let opt = a:1
    let nDirs = s:NoOfPPDirs()

    " Displays the nth entry counting from the left or right (depending on +
    "	or - is used) of the list shown by dirs when invoked without options,
    "	starting with zero.
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

      let dirsStr = s:DirAt(dirIndex)

      " Clears the directory stack by deleting all of the entries.
    elseif opt == "-c"
      let s:dirStack = MvAddElement("", s:dirSep, getcwd())
      let dirsStr = substitute(s:dirStack, s:dirSep, " ", "g")
      " Produces a longer listing; the default list-ing format uses a tilde to
      "   denote the home directory.
    elseif opt == "-l"
      let dirsStr = substitute(s:dirStack, s:dirSep, " ", "g") " For now.

      " Print the directory stack with one entry per line.
    elseif opt == "-p"
      let dirsStr = substitute(substitute(s:dirStack, s:dirSep . '$', '', ''),
	    \ s:dirSep, "\n", "g")

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
    let s:dirStack = MvInsertElementAt(s:dirStack, s:dirSep, getcwd(), 0)
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

  let dirToCd = s:DirAt(1)
  let success = s:ChDir(dirToCd, 'pushd')
  if ! success
    call s:RemoveDirAt(1)
    return 0
  else
    let s:dirStack = MvPushToFrontElementAt(s:dirStack, s:dirSep, 1)
    call PPDirs()
    return 1
  endif
endfunction


" Cd to the directory specified by the dirIndex and make it the first dir.
function! s:PushdIndexImpl(dirIndex)
  let nDirs = s:NoOfPPDirs()
  let dirToCd = s:DirAt(a:dirIndex)
  let success = s:ChDir(dirToCd, 'pushd')
  if ! success
    return 0
  else
    let s:dirStack = MvRotateLeftAt(s:dirStack, s:dirSep, a:dirIndex)
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

  let dirToCd = s:DirAt(1)
  let success = s:ChDir(dirToCd, 'popd')
  if ! success
    call s:RemoveDirAt(1)
    return 0
  else
    call s:RemoveDirAt(0)
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

  call s:RemoveDirAt(a:dirIndex)
  call PPDirs()
  return 1
endfunction


function! s:RemoveDirPromptImpl()
  let nDirs = MvNumberOfElements(&cdpath, ',')
  if nDirs == 0
    echohl ERROR | echo "RemoveDir: cdpath is empty." | echohl NONE
    return 0
  endif

  let curDirIndex = MvIndexOfElement(&cdpath, ',', getcwd())
  let selectedDir = MvPromptForElement(&cdpath, ',', curDirIndex,
	\ "Select the directory: ", -1, s:useDialogs)
  if selectedDir != ""
    return s:RemoveDirImpl(selectedDir)
  endif
endfunction


function! s:RemoveDirIndexImpl(dirIndex)
  let nDirs = MvNumberOfElements(&cdpath, ',')

  let selectedDir = MvElementAt(&cdpath, s:dirSep, a:dirIndex)
  if selectedDir != ''
    return s:RemoveDirImpl(selectedDir)
  endif
endfunction


function! s:RemoveDirImpl(selectedDir)
  if ! MvContainsElement(&cdpath, ',', a:selectedDir)
    echohl ERROR | echo "RemoveDir: . " a:selectedDir . ":" .
	  \ " No such directory in cdpath." | echohl NONE
    return 0
  endif

  let &cdpath = MvRemoveElement(&cdpath, ',', a:selectedDir)
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
  return MvNumberOfElements(s:dirStack, s:dirSep)
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


function! s:DirAt(dirIndex)
  return MvElementAt(s:dirStack, s:dirSep, a:dirIndex)
endfunction


function! s:RemoveDirAt(dirIndex)
  let s:dirStack = MvRemoveElementAt(s:dirStack, s:dirSep, a:dirIndex)
endfunction


function! s:InsertDirAt(dir, dirIndex)
  let s:dirStack = MvInsertElementAt(s:dirStack, s:dirSep, a:dir, a:dirIndex)
endfunction


function! s:StartIterator()
  call MvIterCreate(s:dirStack, s:dirSep, "PushPop")
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


" FIXME: Need a test function.
function! TestPushPop()
endfunction

" vim6:fdm=marker
