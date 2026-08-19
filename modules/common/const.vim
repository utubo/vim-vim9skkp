vim9script

export const update_interval = 50
export const bot_margin = 10
export const cand_width = 8
export const default_zindex = 200
export const default_maxheight = 10
export var roman_table: dict<any> = {}
export var roman_keys: list<string> = []
export var roman_chars: list<string> = []
export var okuri_table: dict<any> = {}
export var arrows = ["\<Left>", "\<Right>", "\<Up>", "\<Down>"]

export enum Type
  Hira(true, 'hira', 'ん', 'っ'),
  Kata(true, 'kata', 'ン', 'ッ'),
  Hank(true, 'hankaku', 'ﾝ', 'ｯ'),
  Alph(false, 'alphabet', 'ｎ', ''),
  Abbr(false, 'abbr', 'n', '')
  var roman: bool
  var label: string
  var n: string
  var ltsu: string
endenum

export var roman_table_base = {
  # 4文字
  ltsu: 'っ', xtsu: 'っ',
  # 3文字
  gya: 'ぎゃ', gyi: 'ぎぃ', gyu: 'ぎゅ', gye: 'ぎぇ', gyo: 'ぎょ',
  zya: 'じゃ', zyi: 'じぃ', zyu: 'じゅ', zye: 'じぇ', zyo: 'じょ',
  dya: 'ぢゃ', dyi: 'でぃ', dyu: 'ぢゅ', dye: 'ぢぇ', dyo: 'ぢょ',
  dha: 'ぢゃ', dhi: 'でぃ', dhu: 'ぢゅ', dhe: 'ぢぇ', dho: 'ぢょ',
  bya: 'びゃ', byi: 'びぃ', byu: 'びゅ', bye: 'びぇ', byo: 'びょ',
  pya: 'ぴゃ', pyi: 'ぴぃ', pyu: 'ぴゅ', pye: 'ぴぇ', pyo: 'ぴょ',
  kya: 'きゃ', kyi: 'きぃ', kyu: 'きゅ', kye: 'きぇ', kyo: 'きょ',
  sya: 'しゃ', syi: 'しぃ', syu: 'しゅ', sye: 'しぇ', syo: 'しょ',
  sha: 'しゃ', shi: 'し',   shu: 'しゅ', she: 'しぇ', sho: 'しょ',
  tya: 'ちゃ', tyi: 'ち',   tyu: 'ちゅ', tye: 'ちぇ', tyo: 'ちょ',
  cha: 'ちゃ', chi: 'ちぃ', chu: 'ちゅ', che: 'ちぇ', cho: 'ちょ',
  tsa: 'つぁ', tsi: 'つぃ', tsu: 'つ',   tse: 'つぇ', tso: 'つぉ',
  tha: 'てゃ', thi: 'てぃ', thu: 'てゅ', the: 'てぇ', tho: 'てょ',
  nya: 'にゃ', nyi: 'にぃ', nyu: 'にゅ', nye: 'にぇ', nyo: 'にょ',
  hya: 'ひゃ', hyi: 'ひぃ', hyu: 'ひゅ', hye: 'ひぇ', hyo: 'ひょ',
  fya: 'ふゃ', fyi: 'ふぃ', fyu: 'ふゅ', fye: 'ふぇ', fyo: 'ふょ',
  mya: 'みゃ', myi: 'みぃ', myu: 'みゅ', mye: 'みぇ', myo: 'みょ',
  rya: 'りゃ', ryi: 'りぃ', ryu: 'りゅ', rye: 'りぇ', ryo: 'りょ',
  lya: 'ゃ', lyu: 'ゅ', lyo: 'ょ', ltu: 'っ', lwa: 'ゎ',
  xya: 'ゃ', xyu: 'ゅ', xyo: 'ょ', xtu: 'っ', xwa: 'ゎ',
  # 2文字
  ja: 'じゃ', ji: 'じ', ju: 'じゅ', je: 'じぇ', jo: 'じょ',
  fa: 'ふぁ', fi: 'ふぃ', fu: 'ふ', fe: 'ふぇ', fo: 'ふぉ',
  va: 'ゔぁ', vi: 'ゔぃ', vu: 'ゔ', ve: 'ゔぇ', vo: 'ゔぉ',
  la: 'ぁ', li: 'ぃ', lu: 'ぅ', le: 'ぇ', lo: 'ぉ',
  xa: 'ぁ', xi: 'ぃ', xu: 'ぅ', xe: 'ぇ', xo: 'ぉ',
  ga: 'が', gi: 'ぎ', gu: 'ぐ', ge: 'げ', go: 'ご',
  za: 'ざ', zi: 'じ', zu: 'ず', ze: 'ぜ', zo: 'ぞ',
  da: 'だ', di: 'ぢ', du: 'づ', de: 'で', do: 'ど',
  ba: 'ば', bi: 'び', bu: 'ぶ', be: 'べ', bo: 'ぼ',
  pa: 'ぱ', pi: 'ぴ', pu: 'ぷ', pe: 'ぺ', po: 'ぽ',
  ka: 'か', ki: 'き', ku: 'く', ke: 'け', ko: 'こ',
  sa: 'さ', si: 'し', su: 'す', se: 'せ', so: 'そ',
  ta: 'た', ti: 'ち', tu: 'つ', te: 'て', to: 'と',
  na: 'な', ni: 'に', nu: 'ぬ', ne: 'ね', no: 'の',
  ha: 'は', hi: 'ひ', hu: 'ふ', he: 'へ', ho: 'ほ',
  ma: 'ま', mi: 'み', mu: 'む', me: 'め', mo: 'も',
  ya: 'や', yi: 'ゐ', yu: 'ゆ', ye: 'ゑ', yo: 'よ',
  ra: 'ら', ri: 'り', ru: 'る', re: 'れ', ro: 'ろ',
  wa: 'わ', wi: 'うぃ', we: 'うぇ', wo: 'を', nn: 'ん',
  # 1文字
  a: 'あ', i: 'い', u: 'う', e: 'え', o: 'お', # n: 'ん',
  # 記号
  'z ': '　', 'z.': '…', 'z/': '・', 'z[': '『', 'z]': '』', 'z-': '～',
  zl: '→', zh: '←', zj: '↓', zk: '↑',
  '[': '「', ']': '」', '-': 'ー', '.': '。', ',': '、',
  '!': '！', '?': '？', '~': '～',
}

for [k, v] in roman_table_base->items()
  okuri_table[v->strcharpart(0, 1)] = k[0]
endfor

export const hira_chars = ('ぁあぃいぅうぇえぉおかがきぎくぐけげこご' ..
  'さざしじすずせぜそぞただちぢっつづてでとど' ..
  'なにぬねのはばぱひびぴふぶぷへべぺほぼぽ' ..
  'まみむめもゃやゅゆょよらりるれろゎわゐゑをんゔー　')->split('.\zs')

export const kata_chars = ('ァアィイゥウェエォオカガキギクグケゲコゴ' ..
  'サザシジスズセゼソゾタダチヂッツヅテデトド' ..
  'ナニヌネノハバパヒビピフブプヘベペホボポ' ..
  'マミムメモャヤュユョヨラリルレロヮワヰヱヲンヴー　')->split('.\zs')

export const hankaku_chars = ('ｧｱｨｲｩｳｪｴｫｵｶｶﾞｷｷﾞｸｸﾞｹｹﾞｺｺﾞ' ..
  'ｻｻﾞｼｼﾞｽｽﾞｾｾﾞｿｿﾞﾀﾀﾞﾁﾁﾞｯﾂﾂﾞﾃﾃﾞﾄﾄﾞ' ..
  'ﾅﾆﾇﾈﾉﾊﾊﾞﾊﾟﾋﾋﾞﾋﾟﾌﾌﾞﾌﾟﾍﾍﾞﾍﾟﾎﾎﾞﾎﾟ' ..
  'ﾏﾐﾑﾒﾓｬﾔｭﾕｮﾖﾗﾘﾙﾚﾛﾜﾜｲｴｦﾝｳﾞｰ ')->split('.[ﾟﾞ]\?\zs')

export const alphabet_chars = ('０１２３４５６７８９' ..
  'ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ' ..
  'ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ' ..
  '　！＂＃＄％＆＇（）－＾＼＠［；：］，．／＼＝～｜｀｛＋＊｝＜＞？＿')->split('.\zs')

export const abbr_chars = ('0123456789' ..
  'abcdefghijklmnopqrstuvwxyz' ..
  'ABCDEFGHIJKLMNOPQRSTUVWXYZ' ..
  ' !"#$%&''()-^\@[;:],./\=~|`{+*}<>?_')->split('.\zs')

