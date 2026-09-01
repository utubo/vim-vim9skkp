vim9script

# tr()の半角カナ対応版
# NOTE: 半角カナ→ひらがなorカタカナはNG(面倒なので対応してないだけ)
export def Tr(str: string, from_chars: list<string>, to_chars: list<string>): string
  var dest = []
  for c in str->split('.\zs')
    const i = from_chars->index(c)
    dest += [i ==# - 1 ? c : to_chars[i]]
  endfor
  return dest->join('')
enddef

# カーソル位置を { col, line }のdictで返す
# NOTE: terminalはどうやってもカーソル位置を取得できない
export def GetCurPos(): dict<any>
  var p = { col: 0, line: 0 }
  if mode() ==# 'c'
    const q = getcmdscreenpos()
    const o = GetEchoOffset()
    const x = q - o
    const w = v:echospace + 1
    return {
      line: &lines - &cmdheight + 1 + x / w,
      col: x % w + o,
    }
  else
    const c = getcurpos()[1 : 2]
    const q = screenpos(0, c[0], c[1])
    return {
      line: min([q.row, &lines]),
      col: q.col,
    }
  endif
enddef

def GetEchoOffset(): number
  const o = &columns - v:echospace
  return !o || &tplo =~# 'right' ? 0 : o
enddef

# カーソル位置の文字を返す
export def GetCharAtCursor(): string
  const m = mode()
  if m ==# 'c'
    return getcmdline()->matchstr($'\%{getcmdpos()}c.')
  else
    return getline('.')->matchstr($'\%{col('.')}c.')
  endif
enddef

# 引数が文字列の場合は文字列のリストにして返す
export def ToList(s: any): list<string>
  if type(s) ==# v:t_string
    return [s]
  else
    return s
  endif
enddef

# 文字列のリストが指定の文字列を含むか返す
# keysがリストでない場合は[keys]として扱う
export def Contains(keys: any, key: string): bool
  if type(keys) ==# v:t_string
    return keys ==# key
  else
    return index(keys, key) !=# -1
  endif
enddef

# 文字列を必ず2つに分割する
export def Split(str: string, dlm: string): list<string>
  const i = str->stridx(dlm)
  return i ==# - 1 ? [str, ''] : [str->strpart(0, i), str->strpart(i + 1)]
enddef

# keyがバックスペースであるか返す
const BS = $'{nr2char(128)}kb'
export def IsBackSpace(key: string): bool
  return key ==# "\<BS>" || key ==? BS
enddef

# ポップアップウインドウが存在するか返す
export def IsPopupExists(id: number): bool
  return !!id && !popup_getpos(id)->empty()
enddef

# 例外が起きてもg:変数にいれて操作不能にならないようにする
export def Silent(F: func)
  try
    F()
  catch
    g:vim9skkp_exception = v:exception
  endtry
enddef

export def IsNormalChar(c: string): bool
  return c ==# ' ' || c ==# c->keytrans()
enddef

export def MergeDicts(...dicts: list<dict<any>>): dict<any>
  var ret = {}
  for d in dicts
    ret->extend(d)
  endfor
  return ret
enddef

