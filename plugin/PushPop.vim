" PushPop.vim -- pushd/popd implementation for VIM
" Author: Hari Krishna Dara <hari_vim@yahoo.com>
" Last Change:  19-Mar-2002 @ 22:47
" Created:      31-Jan-1999
" Requires: Vim-6.0, multvals.vim(2.1.1)
" Version: 2.0.5
" Description:
"   The script provides a pushd/popd functionality for Vim taking Bash as a
"     reference. It defines new commands called Pushd, Popd (and Pud, Pod as
"     shortcuts), Cd and Dirs. It also defines abbreviations pushd, popd, pud,
"     pod cd and dirs (the lower case versions) to make it easy to type and get
"     used to, but if it causes any trouble for you regular command line typing,
"     just set the g:pushpopNoAbbrev variable in your .vimrc.
"   Most of the Bash pushd/popd syntax is supported.
"   It also provides Cdp command to quickly cd to the previous directory,
"     Which works even if you forgot to use the Pushd command and just used
"     the regular Cd command. It also creates a OLDPWD global variable (on the
"     lines of bash) which always contains the name of the previous directory.
"   The Cdc command will push the directory of the current file on to the
"     stack and cd into it.
"   It also exposes the main functions as global functions, which can be used
"     by the script writers to write scripts that can move around in the
"     directory hierarchy and finally leave the working directory as the
"     original.
" Installation:
"   Drop this and multvals.vim in your plugin directory to install it. If you
"     rather want to manually source it, make sure multvals.vim is sourced
"     before sourcing this script.
" Environment:
"   Adds
"       PPInitialize,
"       Pushd, Pud, Popd, Pod, Cd, Cdp, Cdc, Dirs
"     commands.
"   Adds
"       pushd, popd, pud, pod, cd, cdp, cdc, dirs
"     command line abbreviations, if not disabled.
"   Adds
"       Pushd, Popd, Cd, Dirs
"     global functions. 
"
" Incompatibilities:
"   The Bash implementation supports the "-n" option, but it is not supported
"     here as I didn't think it is useful.

if exists("loaded_pushpop")
  finish
endif
let loaded_pushpop = 1


" We need this at the time of initialization itself.
if !exists("loaded_multvals")
  runtime plugin/multvals.vim
endif


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
command! -nargs=? -complete=dir Pud call Pushd(<f-args>)
command! -nargs=? -complete=dir Pushd call Pushd(<f-args>)
command! -nargs=? -complete=dir Dirs call Dirs(<f-args>)
command! -nargs=? -complete=dir Pod call Popd(<f-args>)
command! -nargs=? -complete=dir Popd call Popd(<f-args>)
command! -nargs=? -complete=dir Cd call Cd(<f-args>)
command! -nargs=? -complete=dir Cdp call Cd(g:OLDPWD)
command! -nargs=? -complete=dir Cdc call Pushd(expand("%:p:h"))

if exists("g:pushpopNoAbbrev")
  let s:noAbbrev = g:pushpopNoAbbrev
  unlet g:pushpopNoAbbrev
elseif !exists("s:noAbbrev")
  let s:noAbbrev = 0
endif

if s:noAbbrev
  silent! cuna pud
  silent! cuna pushd
  silent! cuna pod
  silent! cuna popd
  silent! cuna dir
  silent! cuna cd
  silent! cuna cdp
  silent! cuna cdc
else
  ca pud Pud
  ca pushd Pushd
  ca pod Pod
  ca popd Popd
  ca dirs Dirs
  " How nice if there is an autocommand trigger for change directory also?
  ca cd Cd
  ca cdp Cdp
  ca cdc Cdc
endif

" Initialize the directory stack.
let s:dirStack = MvAddElement('', s:dirSep, getcwd())
let g:OLDPWD = getcwd()

endfunction " s:Initialize

call s:Initialize()

"
" The front-end functions.
"

" List out all the directories in the stack.
function! Dirs(...)
  if a:0 == 0
    call s:DirsImpl()
  else " if a:0 == 1
    call s:DirsOptImpl(a:1)
  endif
endfunction


" This should only adjust the top directory in the stack.
function! Cd(newDir)
  if a:newDir == ""
    "let newDir = "~"
  endif
  if ! isdirectory(a:newDir)
    echohl ERROR | echo "cd: " . a:newDir ": No such file or directory" |
        \ echohl NONE
    return
  endif

  call s:CdImpl(a:newDir)
endfunction


" Pushd.
function! Pushd(...)
  if a:0 == 0
    let nDirs = s:NoOfDirs()
    " First check if there are two entries.
    if nDirs == 1
      echohl ERROR | echo "pushd: no other directory" | echohl NONE
      return
    endif

    " Exchange the first two entries.
    call s:PushdNoArgImpl()
  else " if a:0 == 1
    " If a directory name is given, then push it on to the stack.
    if match(a:1, "^[-+]") != 0
      let newDir = a:1
      if ! isdirectory(newDir)
        echohl ERROR | echo "pushd: " . newDir ": No such file or directory" |
            \ echohl NONE
        return
      endif

      call s:PushdImpl(newDir)
    else " An index is given.
      let dirIndex = strpart(a:1, 1)
      if match(dirIndex, '\d\+') == -1
        echohl ERROR | echo "pushd: " . a:1 . ": Invalid argument " |
            \ echohl NONE
        return ""
      endif

      call s:PushdIndexImpl(dirIndex)
    endif
  "else
    " Too many arguments.
  endif
endfunction


" A fron-end to s:PopdImpl()
" Prevents the stack to be emptied.
function! Popd(...)
  let nDirs = s:NoOfDirs()
  " Don't let the stack to be emptied. For us having one directory itself
  " is like it is already empty.
  if nDirs == 1
    echohl ERROR | echo "popd: directory stack empty" | echohl NONE
    return
  endif

  if a:0 == 0
    call s:PopdImpl()
  elseif a:0 == 1 " We expect only an index.
    let dirIndex = strpart(a:1, 1)
    if match(a:1, "+") != 0 || match(dirIndex, '\d\+') == -1
      echohl ERROR | echo "popd: bad argument " . a:1 | echohl NONE
      return
    endif

    " echo "calling with one arg" a:1
    call s:PopdIndexImpl(dirIndex)
  endif
endfunction


"
" Helper functions to hide datastructures.
"

function! s:CdImpl(dir)
  let nDirs = s:NoOfDirs()
  let fullPath = fnamemodify(a:dir, ":p")
  if nDirs == 1
    let s:dirStack = fullPath
  else
    let s:dirStack = MvRemoveElementAt(s:dirStack, s:dirSep, 0)
    let s:dirStack = MvInsertElementAt(s:dirStack, s:dirSep, fullPath, 0)
  endif
  call s:ChDir(a:dir, 0)
endfunction


function! s:DirsImpl()
  echo substitute(s:dirStack, s:dirSep, " ", "g")
endfunction


function! s:DirsOptImpl(opt)
  let nDirs = s:NoOfDirs()

  " Displays the nth entry counting from the left or right (depending on + or -
  "   is used) of the list shown by dirs when invoked without options, starting
  "   with zero.
  if match(a:opt, '^[-+]\d\+') != -1
    let dirIndex = strpart(a:opt, 1)
    if dirIndex < 0 || dirIndex >= nDirs
      echohl ERROR | echo "dirs: " . dirIndex . ": bad directory stack index" |
            \ echohl NONE
      return
    endif
    if match(a:opt, "^-") == 0
      let dirIndex = (nDirs - 1) - dirIndex
    endif

    echo s:DirAt(dirIndex)

  " Clears the directory stack by deleting all of the entries.
  elseif a:opt == "-c"
    let s:dirStack = MvAddElement("", s:dirSep, getcwd())
    call s:DirsImpl()
  " Produces a longer listing; the default list-ing format uses a tilde to
  "   denote the home directory.
  elseif a:opt == "-l"
    call s:DirsImpl() " For now.

  " Print the directory stack with one entry per line.
  elseif a:opt == "-p"
    echo substitute(substitute(s:dirStack, s:dirSep . '$', '', ''), s:dirSep,
            \ "\n", "g")

  " Print the directory stack with one entry per line, prefixing each entry
  "   with its index in the stack.
  elseif a:opt == "-v"
    call MvIterCreate(s:dirStack, s:dirSep, "PushPop")
    let index = 0
    while MvIterHasNext("PushPop")
      echo " " . index . "  " . MvIterNext("PushPop")
      let index = index + 1
    endwhile

  else
    echohl ERROR | echo "dirs: " . a:opt . ": bad argument " | echohl NONE
  endif
endfunction


" Push the directory on to the stack and change directory to it.
function! s:PushdImpl(dir)
  let fullPath = fnamemodify(a:dir, ":p")
  let s:dirStack = MvInsertElementAt(s:dirStack, s:dirSep, fullPath, 0)
  call s:ChDir(a:dir, s:showDirs)
endfunction

" Switch between the top two dirs.
function! s:PushdNoArgImpl()
  let nDirs = s:NoOfDirs()
  if nDirs < 2
    echohl ERROR | echo "pushd: no other direcotyr" | echohl NONE
    return
  endif

  let dirToCd = s:DirAt(1)
  let s:dirStack = MvPushToFrontElementAt(s:dirStack, s:dirSep, 1)
  call s:ChDir(dirToCd, s:showDirs)
endfunction


" Cd to the directory specified by the dirIndex and make it the first dir.
function! s:PushdIndexImpl(dirIndex)
  let nDirs = s:NoOfDirs()
  if a:dirIndex < 0 || a:dirIndex >= nDirs
    echohl ERROR | echo "pushd: " . a:dirIndex . ": bad directory stack index" |
        \ echohl NONE
    return
  endif

  let dirToCd = s:DirAt(a:dirIndex)
  let s:dirStack = MvRotateLeftAt(s:dirStack, s:dirSep, a:dirIndex)
  call s:ChDir(dirToCd, s:showDirs)
endfunction


" Pop the first directory and return it. If the first directory is popped, then
"   change to the new first directory.
function! s:PopdImpl()
  let nDirs = s:NoOfDirs()
  if nDirs == 0
    echohl ERROR | echo "popd: directory stack empty" | echohl NONE
    return
  endif

  call s:RemoveDirAt(0)
  " If this is not the last one which is popped.
  if nDirs > 1
    call s:ChDir(s:DirAt(0), s:showDirs)
  endif
endfunction


function! s:PopdIndexImpl(dirIndex)
  let nDirs = s:NoOfDirs()
  if nDirs == 0
    echohl ERROR | echo "popd: directory stack empty" | echohl NONE
    return
  endif

  if a:dirIndex < 0 || a:dirIndex >= nDirs
    echohl ERROR | echo "popd: " . a:dirIndex . ": bad directory stack index" |
        \ echohl NONE
    return
  else
    call s:RemoveDirAt(a:dirIndex)
    if s:showDirs
      call Dirs()
    endif
  endif
endfunction


function! s:ChDir(dir, showDirs)
  " First save the current dir in g:OLDPWD. 
  let g:OLDPWD = getcwd()

  " echo ":cd" a:dir
  exec ":cd" a:dir
  if a:showDirs
    call Dirs()
  endif
endfunction


" Count the number of directories in the stack.
function! s:NoOfDirs()
  return MvNumberOfElements(s:dirStack, s:dirSep)
endfunction


function! s:DirAt(dirIndex)
  return MvElementAt(s:dirStack, s:dirSep, a:dirIndex)
endfunction


function! s:RemoveDirAt(dirIndex)
  let s:dirStack = MvRemoveElementAt(s:dirStack, s:dirSep, a:dirIndex)
endfunction
