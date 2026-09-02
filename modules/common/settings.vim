vim9script

import '../key/keymap.vim' as KM

export const none = 0
export const marged = 1
export const initialized = 2

export def Initialize()
  var default = {
    jisyo: ['~/SKK-JISYO.L:EUC-JP', '~/SKK-JISYO.*.utf8:UTF8'],
    jisyo_fuzzy: [ '~/SKK-JISYO.emoji.utf8' ],
    jisyo_user: '~/VIM9SKKP-JISYO.user',
    jisyo_recent: '~/VIM9SKKP-JISYO.recent',
    recent_limit: 1000,
    recent_per_yomi: 1,
    fuzzy_limit: 10,
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
    mode_display: 'popup',
    mode_popup_options: {},
    cands_popup_options: {},
    main_popup_options: {},
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
      select: [' '],
      next: "\<Tab>",
      prev: ["\<S-Tab>", 'x'],
      shortcut: '.123456789'->split('\zs'),
      select_kata: [],
      select_direct: [],
      select_upper: [],
      select_lower: [],
      commit: "\<CR>",
      cancel: "\<C-g>",
      delete: "\<C-d>",
      userjisyo: "\<C-u>",
      sticky_shift: 'Q',
      left: "\<Left>",
      right: "\<Right>",
      predict: [],
    },
    roman_table: {},
    roman_abbrev: {},
    sticky_lock: false,
    auto_commit_regex: '[ をヲ、。「」]',
    auto_suggest_regex: '*[っッ]\?[^a-zA-Zっッ]$',
    abbr_with_shift: false,
    getcurpos: vim9skkp#Nop,
    terminal_prompt: 'terminalに入力: ',
    predict: true,
    predict_title: '予測入力',
    hide_cursor: true,
    dumpsize: 0,
    initialized: marged,
  }
  g:vim9skkp = get(g:, 'vim9skkp', {})
  g:vim9skkp->extend(default, 'keep')
  g:vim9skkp.mode_label->extend(default.mode_label, 'keep')
  g:vim9skkp.keymap->extend(default.keymap, 'keep')
  g:vim9skkp.roman_table->extend(default.roman_table, 'keep')
  g:vim9skkp_status = {
    active: false,
    mode: g:vim9skkp.mode_label.off,
    midasi: g:vim9skkp.sticky_lock,
    mode_label: g:vim9skkp.mode_label.off,
    sticky_shift: false,
    is_cand_selected: false,
    cand_width: 0,
    cands_opt: {
      src_roman: '',
      predict: false,
    },
    midasi_text: '',
  }
  KM.Apply()
enddef

def Color()
  hi default Vim9skkp gui=underline cterm=underline
  hi default link Vim9skkpCursor CursorIM
  hi default link Vim9skkpBlur PMenuExtra
  hi default link Vim9skkpMode PMenu
  hi default link Vim9skkpCand PMenu
  hi default link Vim9skkpCandExtra PMenuExtra
  hi default link Vim9skkpCandShortCut PMenuKind
enddef

Color()

augroup vim9skkp-cs
  au! ColorScheme * Color()
augroup END

