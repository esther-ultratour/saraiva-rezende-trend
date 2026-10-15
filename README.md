# Galeria — Edifício Dr. Alberto Drummond (Saraiva de Rezende)

Galeria de imagens/plantas + vídeo para injeção via script no 3DVista, hospedada no AWS S3.

**Empreendimento:** Edifício Dr. Alberto Drummond — Rua da Bandeira, 290 · Região do Lago · Cascavel / PR
**Incorporadora:** Grupo Saraiva de Rezende
**Tema:** taupe + branco (`#998A80` / `#FFFFFF`)

---

## URLs de produção

| Arquivo | URL |
|---------|-----|
| Galeria | `https://skylineip.s3.sa-east-1.amazonaws.com/Tour+Virtual/saraiva-rezende/alberto-drummond/ferramentas/index.html` |
| Vídeo   | `https://skylineip.s3.sa-east-1.amazonaws.com/Tour+Virtual/saraiva-rezende/alberto-drummond/ferramentas/video-gallery.html` |
| Script  | `https://skylineip.s3.sa-east-1.amazonaws.com/Tour+Virtual/saraiva-rezende/alberto-drummond/ferramentas/inject.js` |

**S3 path:** `s3://skylineip/Tour Virtual/saraiva-rezende/alberto-drummond/ferramentas/`

---

## Estrutura de arquivos

```
ferramentas/
├── index.html            ← galeria de imagens + plantas (?mode=imagens | plantas)
├── video-gallery.html    ← player do vídeo
├── inject.js             ← loader leve para injeção no 3DVista
├── deploy.ps1            ← deploy para o S3 (Windows)
├── build_assets.ps1      ← regera assets/ a partir de _originais/ (ffmpeg)
├── assets-map.tsv        ← arquivo entregue → nome final (fonte do build)
├── _originais/           ← material entregue, FORA do git e do deploy
│   ├── imagens/  plantas/  video/  design/
│   └── Dr. Alberto Drummond - book digital.pdf
└── assets/
    ├── brand/            ← logo.svg + bg.svg (do design, animação tocando uma vez)
    ├── fachada/          ← torre (03) + acesso (03)
    ├── areas-comuns/     ← 35 imagens, uma sub-categoria por ambiente
    ├── plantas/          ← 4 plantas humanizadas, fundo branco
    ├── miniaturas/       ← espelha fachada/, areas-comuns/ e plantas/ (grade)
    └── video/            ← vídeo 1080p (gitignored; sobe com -WithVideo)
```

> Pastas e arquivos publicados: **minúsculos, sem espaços e sem acentos** (o S3 é
> case-sensitive e nomes acentuados quebram a URL). Os nomes de exibição, com
> acentuação, ficam em `GALLERY_CONFIG` no `index.html`.

---

## Categorias e nomenclatura

Os nomes de exibição seguem o **book** do empreendimento.

| Categoria | Sub-categorias (ordem do book) |
|-----------|--------------------------------|
| Fachada | — (Fachada × 3 · Acesso × 3) |
| Áreas Comuns | Fire Place · Piscina · Salão de Festas · Espaço Gourmet · Teen Room · Coworking · Lavanderia · Horta Vertical |
| Plantas | Tipologias · Pavimento Tipo · Área de Lazer |

Divergências entre as pastas entregues e o book — **vale o book**:

- A pasta **Fire Place** trazia também duas imagens da **Horta Vertical** (o muro
  com "Nossa Horta"/"Nossos temperos", página própria no book) → separadas.
- **Teen** → "Teen Room"; **Gourmet** → "Espaço Gourmet" (nomes do book e da planta de lazer).
- As plantas vieram em pastas **"64 m²" e "74 m²"**; o book traz
  **1 Suíte e 1 Quarto — 65,91 m² privativos (finais 3, 4, 5 e 6)** e
  **1 Suíte e 2 Quartos — 80,37 m² privativos (finais 1, 2, 7 e 8)**. A galeria usa os do book.

---

## Assets — do material entregue ao WebP

| Uso | Tamanho | Qualidade |
|-----|---------|-----------|
| Lightbox | lado maior ≤ 2600 px (plantas ≤ 3000 px) | q80 (plantas q86) |
| Grade (`miniaturas/`) | lado maior ≤ 900 px (plantas ≤ 1400 px) | q72 (plantas q78) |

**Plantas:** os JPGs vêm com fundo preto. Um colorkey no preto furaria o desenho
(granito, sombras), então o fundo é removido por **flood fill a partir dos cantos** —
só o preto conectado à borda vira branco — e o desenho é recortado na própria caixa.

**Vídeo:** 4K / 267 MB → 1080p / ~17 MB, já **sem as tarjas pretas** gravadas no
arquivo (1920 × 816 úteis). O player usa essa proporção.

**Marca:** os SVGs do design vinham com as animações em `infinite`; o build troca
para `1 both` (tocam uma vez e congelam no quadro final) e encosta o viewBox do logo
no desenho. Com `prefers-reduced-motion` o SVG mostra direto o quadro final.

```powershell
./build_assets.ps1            # só o que falta
./build_assets.ps1 -Force     # tudo
./build_assets.ps1 -Brand     # logo + fundo
./build_assets.ps1 -Video     # vídeo
```

Para acrescentar imagens: jogue o arquivo em `_originais/`, adicione a linha no TSV,
rode o script e registre o item em `GALLERY_CONFIG.items`.

**Tipografia:** Montserrat (Google Fonts), a mesma do texto do book.

---

## Deploy AWS S3

```powershell
./deploy.ps1               # sync (sem o vídeo) + cache-control no HTML/JS
./deploy.ps1 -QuickHtml    # só HTML/JS
./deploy.ps1 -WithVideo    # inclui o vídeo — 1ª vez / ao trocá-lo
```

O sync sobe **apenas** o que a galeria consome (HTML/JS + `assets/brand`, `fachada`,
`areas-comuns`, `plantas`, `miniaturas`, `video`). HTML/JS recebem
`no-cache,no-store,must-revalidate` para o 3DVista nunca servir versão cacheada.

> Sobras do template anterior ainda no disco, fora do deploy: `assets/thumbs/` e
> `fachada-interativa.html` (Aflora Marista). Podem ser apagadas.

---

## Integração 3DVista

Loader no JavaScript global do projeto e chamadas nos botões — trechos prontos em
`3dvista-snippets.md`:

```js
GaleriaImagens(1);      // abre galeria de imagens   · GaleriaImagens(0) fecha
GaleriaPlantas(1);      // abre galeria de plantas    · GaleriaPlantas(0) fecha
AbrirGaleriaVideos(1);  // abre o vídeo               · AbrirGaleriaVideos(0) fecha
```
