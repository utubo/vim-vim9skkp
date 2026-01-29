vim9script

# toggle, enable, disable, terminalだけはキーマッピングする

def Map(lhs: string, keymap: dict<any>, name: string, default: string)
  var keys = get(keymap, name, default)
  if !keys
    return
  endif
  const rhs = $'<Plug>(vim9skkp-{name})'
  for key in type(keys) ==# v:t_string ? [keys] : keys
    if !!key
      execute lhs key->keytrans() rhs
    endif
  endfor
enddef

export def Apply()
  var keymap = get(g:, 'vim9skkp', {})->get('keymap', {})
  Map('noremap!', keymap, 'toggle', "\<C-j>")
  Map('noremap!', keymap, 'enable', '')
  Map('noremap!', keymap, 'disable', '')
  Map('tnoremap', keymap, 'terminal', "\<C-j>")
enddef

