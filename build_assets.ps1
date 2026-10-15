<#
  build_assets.ps1 — Regera assets/ a partir do material entregue em `_originais/`.

  `_originais/` (fora do git) guarda o material como veio da incorporadora:
  imagens/ (JPG 2500 px), plantas/, video/ (4K), design/ (logo + bg em SVG
  animado) e o book em PDF. O de-para render -> nome final fica em
  `assets-map.tsv` (TAB entre as colunas).

    assets/<destino>.webp              imagem do lightbox  (lado maior <= 2600 px, q80)
    assets/miniaturas/<destino>.webp   miniatura da grade  (lado maior <=  900 px, q72)

  Plantas: os JPGs vem com FUNDO PRETO. Um colorkey no preto furaria o
  desenho (granito, sombras, textos escuros), entao o fundo e removido por
  FLOOD FILL a partir dos quatro cantos: so o preto conectado a borda vira
  branco. Depois o desenho e recortado na propria caixa, com margem branca.
  O PNG do lazer ja vem com transparencia e so e assentado sobre branco.

  Uso:
    ./build_assets.ps1            # gera so o que falta
    ./build_assets.ps1 -Force     # regera tudo
    ./build_assets.ps1 -Brand     # regera logo + fundo (SVG) em assets/brand/
    ./build_assets.ps1 -Video     # regera o video (4K -> 1080p)

  Requisito: ffmpeg/ffprobe no PATH (https://ffmpeg.org).
#>

param(
  [switch]$Force,
  [switch]$Brand,
  [switch]$Video
)

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
  Write-Host 'ERRO: ffmpeg nao encontrado no PATH.' -ForegroundColor Red
  exit 1
}

$Src = '_originais'
if (-not (Test-Path -LiteralPath $Src)) {
  Write-Host "ERRO: pasta '$Src' nao encontrada (material original)." -ForegroundColor Red
  exit 1
}

function Ensure-Dir($file) {
  $dir = Split-Path -Parent $file
  if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
}

function Is-Fresh($in, $out) {
  (-not $Force) -and (Test-Path -LiteralPath $out) -and
  ((Get-Item -LiteralPath $out).LastWriteTime -gt (Get-Item -LiteralPath $in).LastWriteTime)
}

function Convert-One($in, $out, $filter, $quality) {
  Ensure-Dir $out
  & ffmpeg -v error -y -i $in -vf $filter -c:v libwebp -quality $quality -compression_level 5 -frames:v 1 $out
  if ($LASTEXITCODE -ne 0) { throw "ffmpeg falhou em $in" }
}

# ── PLANTAS ────────────────────────────────────────────────────────
$PlanFullW  = 3000   # o texto das cotas e miudo: a planta pede mais pixels
$PlanThumbW = 1400

# Fundo preto -> branco por flood fill (so o preto conectado aos cantos).
# A mascara e dilatada 2x para comer a borda antialiasada, que viraria um
# fio escuro em volta do desenho.
function Get-CleanPlan($in, $tmp) {
  $info = (& ffprobe -v error -select_streams v:0 -show_entries stream=width,height,pix_fmt -of csv=p=0 $in).Split(',')
  $w = [int]$info[0]; $h = [int]$info[1]; $fmt = $info[2]
  $mx = $w - 1; $my = $h - 1
  if ($fmt -match 'a') {
    $graph = "[0]format=rgba[p];[1][p]overlay=format=auto,format=rgb24[o]"
  } else {
    $graph = "[0]format=gbrp,split[a][b];" +
      "[b]format=gray,lut=y='if(lt(val,24),0,255)'," +
      "floodfill=x=0:y=0:s0=0:d0=128,floodfill=x=${mx}:y=0:s0=0:d0=128," +
      "floodfill=x=0:y=${my}:s0=0:d0=128,floodfill=x=${mx}:y=${my}:s0=0:d0=128," +
      "lut=y='if(eq(val,128),255,0)',dilation,dilation,format=gbrp[m];" +
      "[1]format=gbrp[w];[a][w][m]maskedmerge,format=rgb24[o]"
  }
  $script = [IO.Path]::GetTempFileName()
  [IO.File]::WriteAllText($script, $graph)
  & ffmpeg -v error -y -i $in -f lavfi -i "color=c=white:s=${w}x${h}" -/filter_complex $script -map '[o]' -frames:v 1 $tmp
  Remove-Item -LiteralPath $script
  if ($LASTEXITCODE -ne 0) { throw "ffmpeg falhou ao limpar $in" }

  # caixa do desenho: negativo + cropdetect (que procura "preto" nas bordas)
  $log = cmd /c "ffmpeg -hide_banner -i `"$tmp`" -vf negate,cropdetect=limit=12:round=2:skip=0 -f null - 2>&1"
  $m = [regex]::Matches(($log -join "`n"), 'crop=(\d+):(\d+):(\d+):(\d+)')
  if ($m.Count -eq 0) { throw "nao achei a caixa do desenho em $in" }
  $g = $m[$m.Count - 1].Groups
  $cw = [int]$g[1].Value; $ch = [int]$g[2].Value; $cx = [int]$g[3].Value; $cy = [int]$g[4].Value
  $pad = [int]([Math]::Max($cw, $ch) * 0.035)
  "crop=${cw}:${ch}:${cx}:${cy},pad=$($cw + 2*$pad):$($ch + 2*$pad):${pad}:${pad}:color=white"
}

$done = 0; $skip = 0
foreach ($line in (Get-Content -LiteralPath 'assets-map.tsv' -Encoding UTF8)) {
  if (-not $line.Trim()) { continue }
  $parts = $line -split "`t"
  $in  = Join-Path $Src $parts[0]
  $dst = $parts[1]
  $full  = "assets/$dst.webp"
  $thumb = "assets/miniaturas/$dst.webp"

  if (-not (Test-Path -LiteralPath $in)) { Write-Host "  falta: $($parts[0])" -ForegroundColor Yellow; continue }
  if ((Is-Fresh $in $full) -and (Is-Fresh $in $thumb)) { $skip++; continue }

  if ($dst -like 'plantas/*') {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("planta-" + (Split-Path -Leaf $dst) + ".png")
    $box = Get-CleanPlan $in $tmp
    Convert-One $tmp $full  "$box,scale='min($PlanFullW,iw)':-2:flags=lanczos"  86
    Convert-One $tmp $thumb "$box,scale='min($PlanThumbW,iw)':-2:flags=lanczos" 78
    Remove-Item -LiteralPath $tmp -ErrorAction SilentlyContinue
  } else {
    Convert-One $in $full  "scale='min(2600,iw)':-2:flags=lanczos" 80
    Convert-One $in $thumb "scale='min(900,iw)':-2:flags=lanczos"  72
  }
  $done++; Write-Host "  $dst" -ForegroundColor DarkGray
}
Write-Host "Imagens: $done geradas, $skip ja atualizadas." -ForegroundColor Green

# ── MARCA ──────────────────────────────────────────────────────────
# Os SVGs do design vem com as animacoes em `infinite`: o logo se
# reescreveria a cada 8 s e o monograma do fundo piscaria a cada 2 s.
# Aqui viram `1 both` — tocam UMA vez e congelam no quadro final (todos os
# keyframes de 100% terminam com opacity 1). ATENCAO: no logo do Trend o
# estado-base (sem animacao) fica desmontado — por isso o reduced-motion NAO
# desliga a animacao, so a reduz a ~0 ms (pula direto para o quadro final).
if ($Brand) {
  New-Item -ItemType Directory -Force -Path 'assets/brand' | Out-Null
  $once    = '(\d+(?:\.\d+)?s linear) infinite'
  $reduced = '@media (prefers-reduced-motion: reduce) { * { animation-duration: 0.001ms !important; animation-delay: 0s !important; } }'
  $utf8    = New-Object System.Text.UTF8Encoding($false)

  $logo = [IO.File]::ReadAllText("$Src/design/logo-trend.svg")
  $logo = [regex]::Replace($logo, $once, '$1 1 both')
  # o quadro de 600 x 600 tem muita sobra em volta: o viewBox encosta no desenho
  $logo = $logo.Replace('width="600" height="600" viewBox="0 0 600 600"', 'width="555" height="437" viewBox="23 82 555 437"')
  $logo = $logo.Replace('</style>', "$reduced`n</style>")
  [IO.File]::WriteAllText("$PSScriptRoot/assets/brand/logo.svg", $logo, $utf8)

  $bg = [IO.File]::ReadAllText("$Src/design/bg-trend.svg")
  $bg = [regex]::Replace($bg, $once, '$1 1 both')
  $bg = $bg.Replace('</style>', "$reduced`n</style>")
  [IO.File]::WriteAllText("$PSScriptRoot/assets/brand/bg.svg", $bg, $utf8)
  Write-Host 'Marca regerada (assets/brand/logo.svg, bg.svg).' -ForegroundColor Green
}

# ── VIDEO ──────────────────────────────────────────────────────────
# 4K -> 1080p H.264 com faststart (comeca a tocar antes de terminar o
# download). AINDA SEM VIDEO DO TREND: o crop (1920 x 816 a partir de y=132)
# veio do filme do Alberto Drummond — medir de novo com cropdetect quando o
# video chegar e ajustar o aspect-ratio em video-gallery.html.
if ($Video) {
  $vin  = "$Src/video/TREND.mp4"
  $vout = 'assets/video/video-trend.mp4'
  Ensure-Dir $vout
  & ffmpeg -v error -y -i $vin -vf "scale=1920:-2:flags=lanczos,crop=1920:816:0:132" -c:v libx264 -preset slow -crf 21 `
      -profile:v high -pix_fmt yuv420p -movflags +faststart -c:a aac -b:a 160k $vout
  if ($LASTEXITCODE -ne 0) { throw 'ffmpeg falhou no video' }
  Write-Host "Video: $vout" -ForegroundColor Green
}
