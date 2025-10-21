vim9script

# 文字の入力と表示するポップアップウィンドウ

import './const.vim' as C
import './util.vim' as U
import './jisyo.vim' as J

const Tr = U.Tr
const Contains = U.Contains

export var winid = 0
export var active = false
export var text = ''
export var chartype = C.Type.Hira
export var midasi = false # NOTE: 処理簡略化のためabbrのときもtrue
export var sticky_shift = false

# 表示制御 {{{
export def Popup()
  if !U.IsPopupExists(winid)
    winid = popup_create('', { zindex: g:vim9skkp.zindex })
  endif
  win_execute(winid, 'syntax match Vim9skkp /./')
  win_execute(winid, 'syntax match Vim9skkpCursor /.$/')
  chartype = C.Type.Hira
  midasi = g:vim9skkp.keep_midasi_mode
  SetText('')
  active = true
enddef

export def Close()
  popup_close(winid)
  winid = 0
  active = false
  redraw
enddef

export def FollowCursor(p: dict<any>)
  popup_move(winid, p)
enddef

export def SetText(_text: string)
  text = _text
  if !text
    # textが空の場合はカーソル位置の文字を空かしておく
    popup_settext(winid, U.GetCharAtCursor() ?? ' ')
  else
    # textの末尾にカーソルを表示
    popup_settext(winid, text .. ' ')
  endif
  doautocmd vim9skkp User vim9skkp-m-settext
enddef
# }}}

# キー入力制御 {{{

# 入力制御の大枠
export def Filter(key: string, mapping: bool): bool
  if FilterImpl(key, mapping)
    SetStickyShift(false)
    return true
  endif
  if mapping
    # 処理対象外なら入力中のものは確定してしまう
    Commit()
    SetStickyShift(false)
  endif
  return false
enddef

# 入力制御のメイン
def FilterImpl(_key: string, mapping: bool): bool
  var key = _key
  if sticky_shift
    key = key->toupper()
  endif
  if U.IsBackSpace(key)
    return BackSpace(mapping)
  elseif InputAlphabet(key)
    return true
  elseif IgnoreKeys(key)
    return true
  elseif CommonFunctions(key)
    return true
  elseif ChangeCharType(key)
    doautocmd User Vim9skkpStatusChanged
    return true
  elseif !!text && g:vim9skkp.keymap.commit->Contains(key)
    Commit()
    return true
  endif
  if key !~ '\p'
    return false
  endif
  doautocmd User vim9skkp-m-before-add-char
  Midasi(key)
  var ret = true
  if Roman(key)
    if !midasi && text !~ '[っッ][a-z]$'
      Commit()
    endif
  elseif mapping
    $'{text}{key->tolower()}'->SetText()
  else
    ret = false
  endif
  if text =~ g:vim9skkp.auto_commit_regex
    Commit()
  endif
  if !!g:vim9skkp.auto_suggest_regex &&
      text =~ g:vim9skkp.auto_suggest_regex
    doautocmd User vim9skkp-m-start
  endif
  return ret
enddef

def SetStickyShift(b: bool)
  if sticky_shift !=# b
    sticky_shift = b
    doautocmd User Vim9skkpStatusChanged
  endif
enddef

def IgnoreKeys(key: string): bool
  return Contains([
    # カーソル移動されると面倒なので
    "\<Left>",
    "\<Right>",
    "\<Up>",
    "\<Down>",
  ], key)
enddef

def CommonFunctions(key: string): bool
  if g:vim9skkp.keymap.toggle->Contains(key)
    doautocmd User vim9skkp-m-toggle
    return true
  elseif g:vim9skkp.keymap.cancel->Contains(key)
    doautocmd User vim9skkp-m-cancel
    return true
  elseif g:vim9skkp.keymap.midasi->Contains(key)
    Commit()
    SetMidasiMode(!midasi)
    return true
  elseif Select(key)
    return true
  elseif g:vim9skkp.keymap.sticky_shift->Contains(key)
    SetStickyShift(true)
    return true
  elseif g:vim9skkp.keymap.userjisyo->Contains(key)
    doautocmd User vim9skkp-userjisyo
    return true
  else
    return false
  endif
enddef

def BackSpace(mapping: bool): bool
  if mapping || !text
    return false
  else
    text
      ->substitute('.$', '', '')
      ->SetText()
  endif
  return true
enddef

def InputAlphabet(key: string): bool
  if C.abbr_chars->index(key) ==# -1
    return false
  elseif chartype ==# C.Type.Abbr
    SetText(text .. key)
    return true
  elseif chartype ==# C.Type.Alph
    SetText(text .. key->Tr(C.abbr_chars, C.alphabet_chars))
    Commit()
    return true
  else
    return false
  endif
enddef

def ToKata(s: string, ct: C.Type): string
  const hira = s
    ->Tr(C.kata_chars, C.hira_chars)
    ->Tr(C.hankaku_chars, C.hira_chars)
  if ct ==# C.Type.Kata
    return hira->Tr(C.hira_chars, C.kata_chars)
  elseif ct ==# C.Type.Hank
    return hira->Tr(C.hira_chars, C.hankaku_chars)
  elseif ct ==# C.Type.Hira
    return hira
  else
    return s
  endif
enddef

export def SetMidasiMode(b: bool)
  if midasi !=# b
    midasi = b
    doautocmd User Vim9skkpStatusChanged
  endif
enddef

def Midasi(key: string): bool
  if key !~ '[A-Z]' ||
      text->stridx(g:vim9skkp.marker_okuri) !=# -1
    return false
  endif
  const m = midasi && !!text ? g:vim9skkp.marker_okuri : ''
  SetMidasiMode(true)
  text
    ->substitute('n$', chartype.n, '')
    ->substitute('$', m, '')
    ->SetText()
  return true
enddef

def Roman(key: string): bool
  const lower = key->tolower()
  const all = text .. lower
  const l = len(all)
  for k in C.roman_keys
    const i = l - len(k)
    if i < 0
      continue
    endif
    if all->strpart(i) !=# k
      continue
    endif
    const r = repeat('.', len(k))
    var v = ToKata(C.roman_table[k], chartype)
    all
      ->substitute($'n{r}$', $'{chartype.n}{r}', '')
      ->substitute($'{r}$', v, '')
      ->SetText()
    return true
  endfor
  return false
enddef

def ChangeCharType(key: string): bool
  const oldtype = chartype
  for t in C.Type.values
    if g:vim9skkp.keymap[t.label]->Contains(key)
      if midasi && !!text
        const before = text
        ToKata(text, t)->SetText()
        J.AddRecent(before, text)
        J.AddHistory(text)
        Commit()
        return true
      else
        noautocmd SetMidasiMode(false)
        noautocmd ToggleCharType(t)
        doautocmd User Vim9skkpStatusChanged
      endif
      break
    endif
  endfor
  return oldtype !=# chartype
enddef

export def ToggleCharType(ct: C.Type)
  if chartype ==# ct
    chartype = C.Type.Hira
  else
    chartype = ct
  endif
  doautocmd User Vim9skkpStatusChanged
enddef

export def Commit()
  var t = text
  if midasi && chartype ==# C.Type.Hira
    t = t->substitute(g:vim9skkp.marker_okuri, '', 'n')
  endif
  if mode() ==# 'c'
    const p = getcmdpos()
    getcmdline()
      ->substitute($'\%{p}c', t, '')
      ->setcmdline(p + t->len())
  else
    var p = getpos('.')
    getline('.')
      ->substitute($'\%{p[2]}c', t, '')
      ->setline('.')
    p[2] += t->len()
    setpos('.', p)
  endif
  SetText('')
  SetMidasiMode(g:vim9skkp.keep_midasi_mode && midasi)
  doautocmd User vim9skkp-m-commit
enddef

def Select(key: string): bool
  if !text
    return false
  elseif !midasi
    return false
  elseif g:vim9skkp.keymap.select->Contains(key)
    doautocmd User vim9skkp-m-start
    return true
  else
    return false
  endif
enddef

export def PreStart()
  if chartype !=# C.Type.Abbr
    text
      ->substitute('n$', chartype.n, '')
      ->SetText()
  endif
enddef
# }}}

