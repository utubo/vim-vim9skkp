vim9script

# 設定 {{{
var default = {
  jisyo: ['~/SKK-JISYO.L:EUC-JP', '~/SKK-JISYO.*.utf8:UTF8'],
  jisyo_user: '~/VIM9SKKP-JISYO.user',
  jisyo_recent: '~/VIM9SKKP-JISYO.recent',
  recent: 1000,
  recent_per_yomi: 1,
  marker_okuri: '*',
  mode_label: {
    off: '_A',
    hira: 'あ',
    kata: 'ア',
    hankaku: 'ｶﾅ',
    alphabet: 'Ａ',
    abbr: 'ab',
    midasi: '▽',
  },
  zindex: 200,
  popup_maxheight: 20,
  search_limit: 100,
  keymap: {
    enable: [],
    disable: [],
    toggle: "\<C-j>",
    terminal: "\<C-j>",
    hira: [],
    kata: 'q',
    hankaku: "\<C-q>",
    alphabet: 'L',
    abbr: '/',
    midasi: 'Q',
    select: [' '],
    next: "\<Tab>",
    prev: ["\<S-Tab>", 'x'],
    shortcut: '.123456789'->split('\zs'),
    commit: "\<CR>",
    cancel: "\<C-g>",
    delete: "\<C-d>",
    userjisyo: "\<C-u>",
    sticky_shift: [],
  },
  roman_table: {},
  keep_midasi_mode: false,
  auto_commit_regex: '[ をヲ、。「」]',
  auto_suggest_regex: '*[っッ]\?[^a-zA-Zっッ]$',
  getcurpos: vim9skkp#NoChangeCurPos,
  hide_cursor: true,
}
g:vim9skkp = get(g:, 'vim9skkp', {})
g:vim9skkp->extend(default, 'keep')
g:vim9skkp.mode_label->extend(default.mode_label, 'keep')
g:vim9skkp.keymap->extend(default.keymap, 'keep')
g:vim9skkp.roman_table->extend(default.roman_table, 'keep')
g:vim9skkp_status = {
  active: false,
  mode: g:vim9skkp.mode_label.off,
  midasi: g:vim9skkp.keep_midasi_mode,
  sticky_shift: false,
  is_cand_selected: false,
}
# }}}

# コマンド {{{
command! Vim9skkpTerminalInput vim9skkp#TerminalInput()
command! Vim9skkpRefreshJisyo vim9skkp#RefreshJisyo()
command! -nargs=? Vim9skkpRegisterToUserJisyo vim9skkp#RegisterToUserJisyo(<q-args>)
# }}}

# キーマッピング {{{
noremap! <Plug>(vim9skkp-toggle) <ScriptCmd>vim9skkp#Toggle()<CR>
noremap! <Plug>(vim9skkp-enable) <ScriptCmd>vim9skkp#Enable()<CR>
noremap! <Plug>(vim9skkp-disable) <ScriptCmd>vim9skkp#Disable()<CR>
tnoremap <Plug>(vim9skkp-terminal) <ScriptCmd>vim9skkp#TerminalInput()<CR>
noremap! <expr> <Plug>(vim9skkp-closepum) pumvisible() ? "\<C-e>": ''

def Map(lhs: string, keys: any, rhs: string)
  if !keys
    return
  endif
  for key in type(keys) ==# v:t_string ? [keys] : keys
    if !!key
      execute lhs key->keytrans() rhs
    endif
  endfor
enddef
Map('noremap!', g:vim9skkp.keymap.toggle, '<Plug>(vim9skkp-toggle)')
Map('noremap!', g:vim9skkp.keymap.enable, '<Plug>(vim9skkp-enable)')
Map('noremap!', g:vim9skkp.keymap.disable, '<Plug>(vim9skkp-disable)')
Map('tnoremap', g:vim9skkp.keymap.terminal, '<Plug>(vim9skkp-terminal)')
# }}}

# 色 {{{
def ColorScheme()
  hi default Vim9skkp gui=underline cterm=underline
  hi default link Vim9skkpCursor CursorIM
  hi default link Vim9skkpBlur PMenuExtra
  hi default link Vim9skkpMode PMenu
  hi default link Vim9skkpCand PMenu
  hi default link Vim9skkpCandExtra PMenuExtra
  hi default link Vim9skkpCandShortCut PMenuKind
enddef

augroup vim9skkp-cs
  autocmd!
  autocmd  ColorScheme * ColorScheme()
augroup END

ColorScheme()
# }}}

