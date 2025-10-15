vim9script

export const update_interval = 50
export const bot_margin = 10
export var roman_table: dict<any> = {}
export var roman_keys: list<string> = []
export var roman_chars: list<string> = []
export var okuri_table: dict<any> = {}

export enum Type
  Hira(true, false, 'hira', 'ん'),
  Kata(true, true, 'kata', 'ン'),
  Hank(true, true, 'hankaku', 'ﾝ'),
  Alph(false, true, 'alphabet', 'ｎ'),
  Abbr(false, false, 'abbr', 'n')
  var roman: bool
  var direct: bool
  var label: string
  var n: string
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
  mya: 'みゃ', myi: 'みぃ', myu: 'みゅ', mye: 'みぇ', myo: 'みょ',
  rya: 'りゃ', ryi: 'りぃ', ryu: 'りゅ', rye: 'りぇ', ryo: 'りょ',
  lya: 'ゃ', lyu: 'ゅ', lyo: 'ょ', ltu: 'っ', lwa: 'ゎ',
  xya: 'ゃ', xyu: 'ゅ', xyo: 'ょ', xtu: 'っ', xwa: 'ゎ',
  # 2文字
  cc: 'っc',
  ja: 'じゃ', ji: 'じ', ju: 'じゅ', je: 'じぇ', jo: 'じょ', jj: 'っj',
  fa: 'ふぁ', fi: 'ふぃ', fu: 'ふ', fe: 'ふぇ', fo: 'ふぉ', ff: 'っf',
  va: 'ゔぁ', vi: 'ゔぃ', vu: 'ゔ', ve: 'ゔぇ', vo: 'ゔぉ',
  la: 'ぁ', li: 'ぃ', lu: 'ぅ', le: 'ぇ', lo: 'ぉ',
  xa: 'ぁ', xi: 'ぃ', xu: 'ぅ', xe: 'ぇ', xo: 'ぉ',
  ga: 'が', gi: 'ぎ', gu: 'ぐ', ge: 'げ', go: 'ご', gg: 'っg',
  za: 'ざ', zi: 'じ', zu: 'ず', ze: 'ぜ', zo: 'ぞ', zz: 'っz',
  da: 'だ', di: 'ぢ', du: 'づ', de: 'で', do: 'ど', dd: 'っd',
  ba: 'ば', bi: 'び', bu: 'ぶ', be: 'べ', bo: 'ぼ', bb: 'っb',
  pa: 'ぱ', pi: 'ぴ', pu: 'ぷ', pe: 'ぺ', po: 'ぽ', pp: 'っp',
  ka: 'か', ki: 'き', ku: 'く', ke: 'け', ko: 'こ', kk: 'っk',
  sa: 'さ', si: 'し', su: 'す', se: 'せ', so: 'そ', ss: 'っs',
  ta: 'た', ti: 'ち', tu: 'つ', te: 'て', to: 'と', tt: 'っt',
  na: 'な', ni: 'に', nu: 'ぬ', ne: 'ね', no: 'の',
  ha: 'は', hi: 'ひ', hu: 'ふ', he: 'へ', ho: 'ほ', hh: 'っh',
  ma: 'ま', mi: 'み', mu: 'む', me: 'め', mo: 'も', mm: 'っm',
  ya: 'や', yi: 'ゐ', yu: 'ゆ', ye: 'ゑ', yo: 'よ', yy: 'っy',
  ra: 'ら', ri: 'り', ru: 'る', re: 'れ', ro: 'ろ', rr: 'っr',
  wa: 'わ', wi: 'うぃ', we: 'うぇ', wo: 'を', nn: 'ん',
  # 1文字
  a: 'あ', i: 'い', u: 'う', e: 'え', o: 'お', # n: 'ん',
  # 記号
  'z ': '　', 'z.': '…', 'z/': '・', 'z[': '『', 'z]': '』', 'z-': '～',
  zl: '→', zh: '←', zj: '↓', zk: '↑',
  '[': '「', ']': '」', '-': 'ー', '.': '。', ',': '、',
  '!': '！', '?': '？', '/': '・', '~': '～',
}

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

