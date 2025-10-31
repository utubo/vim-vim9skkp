vim9script

# 辞書操作関係

import './const.vim' as C
import './util.vim' as U

export const prefix = '>'

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

# 指定したテキスト(ほげ*ふが)に対して[語幹(ほげ), 送り仮名(ふが), 読み(ほげf)]を返す
export def ToJisyoKey(text: string): list<string>
  const [gokan, okuri] = text
    ->Split(g:vim9skkp.marker_okuri)
  const gokan_key = gokan
    ->Tr(C.kata_chars, C.hira_chars)
  const okuri_key = okuri
    ->Tr(C.kata_chars, C.hira_chars)
    ->substitute('^っ*', '', '')
    ->matchstr('^.')
  const yomi = $'{gokan_key}{C.okuri_table->get(okuri_key, '')}' # `ほげf`
  return [gokan, okuri, yomi]
enddef

# 指定したテキスト(ほげ*ふが)に対して[変換候補, 読み(ほげf), 送り仮名(ふが)]を返す
export def GetAllCands(text: string): list<any>
  if !text
    return [[], '', '']
  endif
  const [gokan, okuri, yomi] = ToJisyoKey(text)
  var cands = []
  cands += GetCandsFromJisyo(g:vim9skkp.jisyo_recent, yomi)
    ->filter((k, v): bool => k < g:vim9skkp.recent_per_yomi)
    ->map((k, v): string => $'{v};変換履歴')
  cands += GetCandsFromJisyo(g:vim9skkp.jisyo_user, yomi)
    ->map((k, v): string => $'{v};ユーザー辞書')
  for j in g:vim9skkp.jisyo
    cands += GetCandsFromJisyo(j, yomi)
  endfor
  cands = cands->Uniq()
  # NOTE: 参考
  # https://www.bunka.go.jp/kokugo_nihongo/sisaku/joho/joho/kijun/naikaku/gairai
  if gokan =~# '[ゔーぱぴぷぺぽ]\|[いうくぐしじつとふ][ぁぃぇぉ]\|[てで][ぃぅ]\|ふゅ\|ちぇ'
    cands += [U.Tr(gokan, C.hira_chars, C.kata_chars) .. ';外来語']
  endif
  cands += [$'{gokan};無変換']
  return [cands, yomi, okuri]
enddef
# }}}

# 辞書操作 {{{
export def ExpandPaths(paths: list<string>): list<string>
  var expanded = []
  for j in paths
    const [path, enc] = ToFullPathAndEncode(j)
    for p in path->split('\n')
      expanded += [$'{p}:{enc}']
    endfor
  endfor
  return expanded
enddef

def SaveRecent()
  var lines = ReadRecent().lines
  if !!lines
    WriteJisyo(lines, g:vim9skkp.jisyo_recent)
  endif
enddef

def SetSaveRecent()
  augroup vim9skkp-recent
    au! VimLeavePre * SaveRecent()
  augroup END
enddef

def ToFullPathAndEncode(path: string): list<string>
  const m = path->matchlist('\(.\+\):\([a-zA-Z0-9-]*\)$')
  var p = ''
  var e = ''
  if !m
    p = path
    if path =~ '\.utf8$'
      e = 'UTF8'
    elseif path =~ '[\\/]SKK-JISYO\.[SLM]\+$'
      e = 'EUC-JP'
    endif
  else
    p = m[1]
    e = m[2]
  endif
  return [expand(p), e]
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
  if jisyo->has_key(g:vim9skkp.jisyo_user)
    jisyo[g:vim9skkp.jisyo_user].lines =
      ReadJisyo(g:vim9skkp.jisyo_user)->DeleteCandFromJisyo(c)
    WriteJisyo(jisyo[g:vim9skkp.jisyo_user].lines, g:vim9skkp.jisyo_user)
  endif
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
      const excluded  = v->split('/')->ExcludeCand(cand)
      if !!excluded
        newlines += [$'{k} /{excluded}/'->IconvTo(j.enc)]
      endif
    else
      newlines += [line]
    endif
  endfor
  return newlines
enddef
# }}}

# 変換履歴と入力履歴 {{{
export def AddRecent(_before: string, _after: string)
  if !_after || _after =~ ';入力履歴$'
    return
  endif
  const [before, after] = _after =~ ';変換履歴 .\+'
    ? FromRecentCand(_after)
    : [_before, _after->substitute(';.*', '', '')]
  # 新規に追加する行
  const afters = GetCandsFromJisyo(g:vim9skkp.jisyo_recent, before)
    ->insert(after)
    ->Uniq()
    ->join('/')
  # 送り仮名を考慮
  const [_, __, yomi] = ToJisyoKey(before)
  # 既存の行を削除してから先頭に追加する
  var j = ReadRecent()
  const head = $'{before} '->IconvTo(j.enc)
  const head2 = $'{yomi} '->IconvTo(j.enc)
  j.lines
    ->filter((_, v) => !v->StartsWith(head) && !v->StartsWith(head2))
    ->insert($'{before} /{afters}/'->IconvTo(j.enc))
  if before !=# yomi
    j.lines->insert($'{yomi} /{afters}/'->IconvTo(j.enc))
  endif
  j.lines = j.lines->slice(0, g:vim9skkp.recent)
  # 候補探索用の辞書にはソート済のものをセットする
  jisyo[g:vim9skkp.jisyo_recent] = {
    lines: j.lines->copy()->sort(),
    enc: j.enc,
  }
  SetSaveRecent()
enddef

def GetRecent(text: string): list<string>
  if !text
    return []
  endif
  const j = ReadRecent()
  const head = text->IconvTo(j.enc)
  var cands = []
  for l in j.lines
    if l->StartsWith(head)
      const kv = l->IconvFrom(j.enc)->Split(' ')
      cands += kv[1]
        ->split('/')
        ->map((k, v): string => ToRecentCand(v, kv[0]))
    endif
  endfor
  return cands
enddef

def ToRecentCand(cand: string, yomi: string): string
  const okuri = yomi->Split(g:vim9skkp.marker_okuri)[1]
  return $'{cand}{okuri};変換履歴 {yomi}'
enddef

def FromRecentCand(_cand: string): list<string>
  const yomi = _cand->substitute('^.*;変換履歴 ', '', '')
  const okuri = _cand->Split(g:vim9skkp.marker_okuri)[1]
  const cand = _cand->substitute($'{okuri};変換履歴 .*$', '', '')
  return [yomi, cand]
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
  return (GetHistory(text) + GetRecent(text))->Uniq()
enddef
# }}}

export def RefreshJisyo()
  jisyo = {}
  recent = {}
  echo '辞書をリフレッシュしました'
enddef
