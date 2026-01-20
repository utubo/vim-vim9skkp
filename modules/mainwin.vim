vim9script

# 文字入力ポップアップウィンドウ

import './const.vim' as C
import './util.vim' as U
import './jisyo.vim' as J
import './keyhook.vim' as K

const Tr = U.Tr
const Contains = U.Contains

export var winid = 0
export var active = false
export var text = ''
export var chartype = C.Type.Hira
export var midasi = false
export var sticky_shift = false
export var prevent_redraw = false

# 表示制御 {{{
export def Popup()
  if !U.IsPopupExists(winid)
    winid = popup_create('', { zindex: g:vim9skkp.zindex })
  endif
  win_execute(winid, 'syntax match Vim9skkp /./')
  win_execute(winid, 'syntax match Vim9skkpCursor /.$/')
  if g:vim9skkp.showmode ==# 'cursor'
    for l in values(g:vim9skkp.mode_label)
      win_execute(winid, $'syntax match Vim9skkpCursor /{l->escape('/\')}$/')
    endfor
  endif
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
  if prevent_redraw
    return
  endif
  popup_move(winid, p)
  if !text
    RedrawText()
  endif
enddef

export def SetText(_text: string)
  if text ==# _text
    return
  endif
  text = _text
  RedrawText()
  doautocmd User vim9skkp-m-settext
enddef

export def RedrawText()
  if prevent_redraw
    return
  endif
  if g:vim9skkp.showmode ==# 'cursor'
    const cur = midasi
      ? g:vim9skkp.mode_label.midasi
      : g:vim9skkp_status.mode
    popup_settext(winid, text .. cur)
  elseif !text
    # textが空の場合はカーソル位置の文字を空かしておく
    popup_settext(winid, U.GetCharAtCursor() ?? ' ')
  else
    # textの末尾にカーソルを表示
    popup_settext(winid, text .. ' ')
  endif
enddef

# ちらつき防止
def SetRedrawAfterFeedKeys()
  prevent_redraw = true
  timer_start(1, (_) => {
    prevent_redraw = false
    const c = g:vim9skkp.getcurpos(U.GetCurPos())
    FollowCursor(c)
    RedrawText()
  })
enddef
# }}}

# キー入力制御 {{{

var new_sticky_shift = false # TODO: このフラグはいまいち…

# 入力制御の大枠
export def Filter(key: string, mapping: bool): bool
  new_sticky_shift = false
  const done = key
    ->ApplyStickyShift()
    ->FilterImpl(mapping)
  if done
    SetStickyShift(new_sticky_shift)
    return true
  elseif !mapping
    # マッピング後のキーをkeyhook#Filterから貰うため一旦falseで返す
    return false
  endif

  # マッピング後のキーでもやることが無かった場合
  SetStickyShift(false)
  if !!text
    Commit(key)
    return true
  else
    return false
  endif
enddef

# 入力制御のメイン
def FilterImpl(key: string, mapping: bool): bool
  if mapping && key ==# "\<Esc>"
    return false
  elseif mapping && C.arrows->Contains(key)
    # NOTE: 入力が入ったままカーソル移動されると色々と面倒なので…
    return !!text
  elseif U.IsBackSpace(key)
    return BackSpace(mapping)
  elseif StartSelect(key)
    return true
  elseif InputAlphabet(key, mapping)
    return !mapping
  elseif InputVowel(key)
    return true
  elseif CommonFunctions(key)
    return true
  elseif InputConsonant(key, mapping)
    return true
  else
    return false
  endif
enddef

def AfterAddChar()
  if text =~ g:vim9skkp.auto_commit_regex
    Commit()
  endif
  if !!g:vim9skkp.auto_suggest_regex &&
      text =~ g:vim9skkp.auto_suggest_regex
    StartSelect()
  endif
enddef

def ApplyStickyShift(key: string): string
  return sticky_shift ? key->toupper() : key
enddef

def SetStickyShift(b: bool)
  if sticky_shift !=# b
    sticky_shift = b
    doautocmd User Vim9skkpStatusChanged
  endif
enddef

def CommonFunctions(key: string): bool
  if g:vim9skkp.keymap.toggle->Contains(key)
    doautocmd User vim9skkp-m-toggle
    return true
  elseif g:vim9skkp.keymap.cancel->Contains(key)
    doautocmd User vim9skkp-m-cancel
    return true
  elseif g:vim9skkp.keymap.sticky_shift->Contains(key)
    new_sticky_shift = !sticky_shift
    # NOTE:
    # stick_shiftで見出しモードに遷移できるのと同様に、
    # stick_shiftで見出しモードから抜けられるようにする
    if !new_sticky_shift
      midasi = false
    endif
    return true
  elseif g:vim9skkp.keymap.userjisyo->Contains(key)
    doautocmd User vim9skkp-userjisyo
    return true
  elseif ChangeCharType(key)
    doautocmd User Vim9skkpStatusChanged
    return true
  elseif !!text &&
      (midasi || chartype ==# C.Type.Abbr) &&
      g:vim9skkp.keymap.commit->Contains(key)
    Commit()
    return true
  elseif midasi && key ==# J.prefix
    Commit()
    SetText(J.prefix)
    return true
  else
    return false
  endif
enddef

def BackSpace(mapping: bool): bool
  if mapping || !text
    return false
  endif
  text
    ->substitute('.$', '', '')
    ->SetText()
  return true
enddef

def InputAlphabet(key: string, mapping: bool): bool
  if chartype.roman
    return false
  elseif C.abbr_chars->index(key) ==# -1
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
    silent! doautocmd User Vim9skkpStatusChanged
  endif
enddef

def InputVowel(key: string): bool
  if !chartype.roman
    return false
  endif
  ProcessMidasi(key)
  var [newtext, is_abbr] = AddVowel(key)
  if newtext !=# text
    if g:vim9skkp_status.is_cand_selected
      newtext = newtext[strchars(text) :]
      Commit()
    endif
    SetText(newtext)
    if is_abbr || !midasi && text !~ '[っッｯ][a-z]$'
      Commit()
    endif
    AfterAddChar()
    return true
  endif
  return false
enddef

def ProcessMidasi(key: string): bool
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

def AddVowel(key: string): list<any>
  var is_abbr = false
  const newtext = text .. key->tolower()
  const l = len(newtext)
  for k in g:vim9skkp.roman_abbrev->keys() + C.roman_keys
    const i = l - len(k)
    if i < 0
      continue
    endif
    if newtext->strpart(i) !=# k
      continue
    endif
    var v = get(g:vim9skkp.roman_abbrev, k, '')
    if !!v
      is_abbr = true
    else
      v = C.roman_table[k]
    endif
    if !v
      # NOTE: roman_tableの値に空文字を指定して無効にした場合
      continue
    endif
    if chartype !=# C.Type.Hira
      v = v->ToKata(chartype)
    endif
    const r = repeat('.', len(k))
    return [newtext
      ->substitute($'n{r}$', $'{chartype.n}{r}', '')
      ->substitute($'{r}$', v, ''), is_abbr]
  endfor
  return [text, is_abbr]
enddef

def InputConsonant(key: string, mapping: bool): bool
  if !mapping || !U.IsNormalChar(key)
    return false
  endif
  if g:vim9skkp_status.is_cand_selected
    Commit()
  endif
  const low = key->tolower()
  if C.roman_chars->Contains(low)
    SetText($'{text}{low}')
    AfterAddChar()
  else
    SetText($'{text}{key}')
    Commit()
  endif
  return true
enddef

def ChangeCharType(key: string): bool
  const oldtype = chartype
  for ct in C.Type.values
    if g:vim9skkp.keymap[ct.label]->Contains(key)
      if midasi && !!text
        const before = text
        text
          ->substitute($'n$', $'{chartype.n}', '')
          ->ToKata(ct)
          ->SetText()
        J.AddRecent(before, text)
        Commit()
        return true
      else
        noautocmd SetMidasiMode(false)
        noautocmd ToggleCharType(ct)
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
  silent! doautocmd User Vim9skkpStatusChanged
enddef

export def Commit(key: string = '')
  SetRedrawAfterFeedKeys()
  if midasi && chartype ==# C.Type.Hira
    text = text->substitute(g:vim9skkp.marker_okuri, '', 'n')
  endif
  J.AddHistory(text)
  K.FeedKeys($'{text}{key}', !!key)
  SetText('')
  if chartype ==# C.Type.Abbr
    ToggleCharType(C.Type.Abbr)
    midasi = g:vim9skkp.keep_midasi_mode
  endif
  SetMidasiMode(g:vim9skkp.keep_midasi_mode && midasi)
  doautocmd User vim9skkp-m-commit
enddef

def StartSelect(key: string = ''): bool
  if !text
    return false
  elseif g:vim9skkp_status.is_cand_selected
    return false
  elseif !midasi && chartype !=# C.Type.Abbr
    return false
  elseif !!key && !g:vim9skkp.keymap.select->Contains(key)
    return false
  endif
  text
    ->substitute('n$', chartype.n, '')
    ->SetText()
  doautocmd User vim9skkp-m-start
  return true
enddef
# }}}

