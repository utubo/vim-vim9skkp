vim9script

noremap! <Plug>(vim9skkp-toggle) <ScriptCmd>vim9skkp#Toggle()<CR>
noremap! <Plug>(vim9skkp-enable) <ScriptCmd>vim9skkp#Enable()<CR>
noremap! <Plug>(vim9skkp-disable) <ScriptCmd>vim9skkp#Disable()<CR>
tnoremap <Plug>(vim9skkp-terminal) <ScriptCmd>vim9skkp#TerminalInput()<CR>
noremap! <expr> <Plug>(vim9skkp-closepum) pumvisible() ? "\<C-e>": ''

command! Vim9skkpTerminalInput vim9skkp#TerminalInput()
command! Vim9skkpRefreshJisyo vim9skkp#RefreshJisyo()
command! -nargs=? Vim9skkpRegisterToUserJisyo vim9skkp#RegisterToUserJisyo(<q-args>)

import '../modules/keymap.vim' as KM
KM.Apply()
