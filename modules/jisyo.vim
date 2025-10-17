vim9script

# 辞書操作関係

import './const.vim' as C
import './util.vim' as U

var jisyo = {}
var recent = {}
var is_registering_user_jisyo = false
var history = {}
var last_input = ''

# アローが使えない関数への対応 {{{
const Tr = U.Tr
const Contains = U.Contains
# }}}

# ユーティリティー {{{
def IconvTo(str: string, enc: string): string
  return (!str || !enc || enc ==# &enc) ? str : str->iconv(&enc, enc)
enddef

def IconvFrom(str: string, enc: string): string
  return (!str || !enc || enc ==# &enc) ? str : str->iconv(enc, &enc)
enddef

def StartsWith(str: string, expr: string): bool
  return str->strcharpart(0, expr->strchars()) ==# expr
enddef

# 文字列を必ず2つに分割する
def Split(str: string, dlm: string): list<string>
  const i = str->stridx(dlm)
  return i ==# - 1 ? [str, ''] : [str->strpart(0, i), str->strpart(i + 1)]
enddef

# 順番を保ったままuniqする
def Uniq(list: list<any>): list<any>
  var result = []
  for a in list
    if result->index(a) ==# -1
      result->add(a)
    endif
  endfor
  return result
enddef
# }}}

# 候補取得 {{{
# 辞書ファイルから指定の文字列+空白で始まる行を返す
def GetCandsFromJisyo(path: string, key: string): list<string>
  const j = ReadJisyo(path)
  const head = $'{key} '->IconvTo(j.enc)
  const max = len(j.lines) - 1
  if max < 0
    return []
  endif
  var limit = g:vim9skkp.search_limit
  var d = max
  var i = max / 2
  while !!limit
    limit -= 1
    const line = j.lines[i]
    if line->StartsWith(head)
      return line->IconvFrom(j.enc)->Split(' ')[1]->split('/')
    endif
    d = d / 2 + d % 2
    if d <= 1
      if !!limit
        # 残りの探索が奇数個だと取り漏らすので、あと1回だけ探索がんばる
        limit = 1
        d = 1
      else
        # もうだめ
        break
      endif
    endif
    i += line < head ? d : -d
    i = i < 0 ? 0 : max < i ? max : i
  endwhile
  return []
enddef

# 指定したテキスト(ほげ*ふが)に対して[変換候補, 読み(ほげf), 送り仮名(ふが)]を返す
export def GetAllCands(text: string): list<any>
  if !text
    return [[], '', '']
  endif
  # `▽ほげ*ふが`を語幹と送り仮名に分割する
  const [gokan, okuri] = text
    ->Split(g:vim9skkp.marker_okuri)
  var cands = [$'{gokan};無変換'] # 候補一つ目は無変換
  # 候補を検索する
  const gokan_key = gokan
    ->Tr(C.kata_chars, C.hira_chars)
  const okuri_key = okuri
    ->Tr(C.kata_chars, C.hira_chars)
    ->substitute('^っ*', '', '')
    ->matchstr('^.')
  const yomi = $'{gokan_key}{C.okuri_table->get(okuri_key, '')}' # `ほげf`
  cands += GetCandsFromJisyo(g:vim9skkp.jisyo_recent, yomi)
    ->map((k, v): string => $'{v};変換履歴')
  cands += GetCandsFromJisyo(g:vim9skkp.jisyo_user, yomi)
    ->map((k, v): string => $'{v};ユーザー辞書')
  for j in g:vim9skkp.jisyo
    cands += GetCandsFromJisyo(j, yomi)
  endfor
  cands = cands->Uniq()
  if len(cands) ==# 1 && gokan =~# '[ゔーぱぴぷぺぽ]'
    cands += [U.Tr(gokan, C.hira_chars, C.kata_chars)]
  endif
  return [cands, yomi, okuri]
enddef
# }}}

# 辞書操作 {{{
def SaveRecent()
  var lines = ReadRecent().lines
  if !!lines
    WriteJisyo(lines, g:vim9skkp.jisyo_recent)
  endif
enddef

def SetSaveRecent()
  augroup vim9skkp-recent
    au!
    au VimLeavePre * SaveRecent()
  augroup END
enddef

def ToFullPathAndEncode(path: string): list<string>
  const m = path->matchlist('\(.\+\):\([a-zA-Z0-9-]*\)$')
  return !m ? [expand(path), ''] : [expand(m[1]), m[2]]
enddef

export def ReadJisyo(path: string): dict<any>
  # キャッシュ済み
  if jisyo->has_key(path)
    return jisyo[path]
  endif
  # 読み込んでスクリプトローカルにキャッシュする
  const [p, enc] = ToFullPathAndEncode(path)
  if !filereadable(p)
    # 後から辞書ファイルを置かれる可能性があるので、キャッシュしない
    return { lines: [], enc: enc }
  endif
  # iconvはWindowsですごく重いので、読み込み時には全体を変換しない
  # 検索時に検索対象の方の文字コードを辞書にあわせる
  jisyo[path] = { lines: readfile(p)->sort(), enc: enc }
  return jisyo[path]
enddef

def WriteJisyo(lines: list<string>, path: string, flags: string = '')
  const [p, _] = ToFullPathAndEncode(path)
  if writefile(lines, p, flags) ==# -1
    echoe 'Failed to write {b}.'
  endif
enddef

export def AddUserWord(key: string, value: string): bool
  var j = ReadJisyo(g:vim9skkp.jisyo_user)
  const newline = $'{key} /{value}/'->IconvTo(j.enc)
  if index(j.lines, newline) !=# -1
    return false
  endif
  j.lines += [newline]
  WriteJisyo(j.lines, g:vim9skkp.jisyo_user, 'a')
  # 候補探索用の辞書にはソート済のものをセットする
  jisyo[g:vim9skkp.jisyo_user] = {
    lines: j.lines->copy()->sort(),
    enc: j.enc,
  }
  return true
enddef

def ReadRecent(): dict<any>
  if empty(recent)
    const [p, enc] = ToFullPathAndEncode(g:vim9skkp.jisyo_recent)
    recent = filereadable(p) ?
      { lines: readfile(p), enc: enc } :
      { lines: [], enc: enc }
  endif
  return recent
enddef

def ExcludeCand(cands: list<string>, cand: string): list<string>
  return cands->filter((i, vv) => vv->split(';')[0] !=# cand)
enddef

export def DeleteCand(cands: list<string>, cand: string): list<string>
  const c = cand->split(';')[0]
  if !c
    return cands
  endif
  recent.lines = ReadRecent()->DeleteCandFromJisyo(c)
  SetSaveRecent()
  jisyo[g:vim9skkp.jisyo_user].lines =
    ReadJisyo(g:vim9skkp.jisyo_user)->DeleteCandFromJisyo(c)
  WriteJisyo(jisyo[g:vim9skkp.jisyo_user].lines, g:vim9skkp.jisyo_user)
  return cands->ExcludeCand(c)
enddef

def DeleteCandFromJisyo(j: any, cand: string): list<string>
  const e = cand->IconvTo(j.enc)
  const w = $'/{e}/'
  const w2 = $'/{e};'
  var newlines = []
  for line in j.lines
    if line->stridx(w) !=# -1 || line->stridx(w2) !=# -1
      var [k, v] = line->IconvFrom(j.enc)->Split(' ')
      v = v->split('/')->ExcludeCand(cand)->join('/')
      newlines += [$'{k} /{v}/'->IconvTo(j.enc)]
    else
      newlines += [line]
    endif
  endfor
  return newlines
enddef
# }}}

# 変換履歴と入力履歴 {{{
export def AddRecent(before: string, after: string)
  if !before || !after
    return
  endif
  # 新規に追加する行
  const afters = GetCandsFromJisyo(g:vim9skkp.jisyo_recent, before)
    ->insert(after->substitute(';.*', '', ''))
    ->Uniq()
    ->join('/')
  const newline = $'{before} /{afters}/'
  # 既存の行を削除してから先頭に追加する
  var j = ReadRecent()
  const head = $'{before} '->IconvTo(j.enc)
  j.lines = j.lines
    ->filter((_, v) => !v->StartsWith(head))
    ->slice(0, g:vim9skkp.recent)
    ->insert(newline->IconvTo(j.enc))
  # 候補探索用の辞書にはソート済のものをセットする
  jisyo[g:vim9skkp.jisyo_recent] = {
    lines: j.lines->copy()->sort(),
    enc: j.enc,
  }
  SetSaveRecent()
enddef

def GetRecent(text: string, detail: string = '変換履歴'): list<string>
  if !text
    return []
  endif
  const j = ReadRecent()
  const head = text->IconvTo(j.enc)
  var cands = []
  for l in j.lines
    if l->StartsWith(head)
      cands += l
        ->IconvFrom(j.enc)
        ->Split(' ')[1]
        ->split('/')
    endif
  endfor
  return cands
    ->Uniq()
    ->map((k, v): string => $'{v};{detail}')
enddef

export def AddHistory(next_word: string)
  if !!last_input && !!next_word
    history[last_input] = history
      ->get(last_input, [])
      ->insert(next_word)
      ->Uniq()
  endif
  last_input = next_word
enddef

export def ReadyHistory()
  last_input = ''
enddef

export def GetHistory(text: string = ''): list<string>
  if history->has_key(last_input)
    return history[last_input]
      ->filter((k, v) => !text || v->StartsWith(text))
      ->map((k, v) => $'{v};入力履歴')
  else
    return []
  endif
enddef

export def GetRecentAndHistory(text: string): list<string>
  return (GetHistory(text) + GetRecent(text, '変換履歴'))->Uniq()
enddef
# }}}

export def RefreshJisyo()
  jisyo = {}
  recent = {}
  echo '辞書をリフレッシュしました'
enddef
