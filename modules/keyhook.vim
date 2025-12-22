vim9script

# <Space>等が他のプラグインの影響を受けやすいので
# ポップアップではmapping: false/trueの両方で入力を受け取る
# とか面倒なことはここで吸収する

const st_enabled = 1
const st_feedkeys = 2
const st_queueing = 3
export var state = st_enabled

var winid = 0
var filters = []

# FeedKeys {{{
var queue = ''

export def FeedKeys(keys: string, async: bool)
  if !queue && !async
    queue = keys
    FeedKeysImpl()
  else
    state = st_queueing
    queue ..= keys
    timer_start(0, FeedKeysImpl)
  endif
enddef

export def FeedKeysImpl(_: number = 0)
  state = st_feedkeys
  feedkeys(queue, 'nt')
  feedkeys($"\<Cmd>call vim9skkp#SetKeyHookState({st_enabled})\<CR>", 'nt')
  queue = ''
enddef
# }}}

# キー処理メイン {{{
var mapping = false
var ctrlr = false
var ignore_ctrle = false

export def SetupKeyHook(_winid: number, _filters: list<func>)
  winid = _winid
  filters = _filters
  popup_setoptions(winid, {
    mapping: false,
    filter: Filter,
    filtermode: 'ic',
  })
  mapping = false
  ctrlr = false
  # TODO: 補完プラグインなどが起動直後にCTRL-Eを投げてくることがあるので一時凌ぎ
  ignore_ctrle = true
  timer_start(30, (_) => {
    ignore_ctrle = false
  })
enddef

def Filter(_: number, key: string): bool
  Dump(key)
  if key ==# "\<CursorHold>"
    return false
  elseif state ==# st_feedkeys
    return false
  elseif state ==# st_queueing
    queue ..= key
    return true
  elseif CtrlR(key)
    return false
  elseif IsHalfWayMappingAndKeepAMode(key)
    return false
  elseif ignore_ctrle && key ==# "\<C-E>"
    return false
  endif

  # マッピング済みの入力を受け取ったらポップアップのmappingを元に戻しておく
  const m = mapping # 元の値は各Filterを呼ぶときに渡す
  if m
    SetMapping(false)
  endif

  # キー処理メイン
  for f in filters
    if call(f, [key, m])
      return true
    endif
  endfor

  if m || state('m') ==# 'm'
    # マッピング適用済みでやることがなかった場合
    return false
  else
    # マッピング未適用の入力なら
    # 一旦mapping: trueにして入力をFilterで受けなおす
    SetMapping(true)
    feedkeys(key, 'i')
    return true
  endif
enddef

def SetMapping(b: bool)
  popup_setoptions(winid, { mapping: b })
  mapping = b
enddef

def CtrlR(key: string): bool
  if ctrlr
    return true
  elseif key ==# "\<C-r>" || key ==# "\<Cmd>" || key ==# "\<ScriptCmd>"
    ctrlr = true
    timer_start(0, (_) => {
      ctrlr = false
    })
    return true
  else
    return false
  endif
enddef

def IsHalfWayMappingAndKeepAMode(key: string): bool
  return mapping && key !=# "\<ESC>" && state('m') !=# ''
enddef
# }}}

# デバッグ用 {{{
var dump = []

def Dump(key: string)
  if !g:vim9skkp.dumpsize
    return
  endif
  dump->add({
    key: key, state: state, mapping: mapping, ctrlr: ctrlr,
  })
  const offset = len(dump) - g:vim9skkp.dumpsize
  if 0 < offset
    dump->remove(0, offset)
  endif
enddef

export def ShowDump()
  for d in dump
    echo $'key:{d.key} {char2nr(d.key)} state:{d.state} mapping:{d.mapping} ctrlr:{d.ctrlr}'
  endfor
enddef
# }}}
