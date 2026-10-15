# Galeria — Trend (Saraiva de Rezende)

Galeria de imagens/plantas (+ player de vídeo) para injeção via script no 3DVista, hospedada no AWS S3.

**Empreendimento:** Trend — Região do Lago · Cascavel / PR
**Incorporadora:** Grupo Saraiva de Rezende
**Tema:** verde + creme (`#45923A` / `#E8E4D5`)

---

## URLs de produção

| Arquivo | URL |
|---------|-----|
| Galeria | `https://skylineip.s3.sa-east-1.amazonaws.com/Tour+Virtual/saraiva-rezende/trend/ferramentas/index.html` |
| Vídeo   | `https://skylineip.s3.sa-east-1.amazonaws.com/Tour+Virtual/saraiva-rezende/trend/ferramentas/video-gallery.html` |
| Script  | `https://skylineip.s3.sa-east-1.amazonaws.com/Tour+Virtual/saraiva-rezende/trend/ferramentas/inject.js` |

**S3 path:** `s3://skylineip/Tour Virtual/saraiva-rezende/trend/ferramentas/`

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
│   ├── imagens/  plantas/  design/
└── assets/
    ├── brand/            ← logo.svg + bg.svg (do design, animação tocando uma vez)
    ├── fachada/          ← torre (03) + acesso (03)
    ├── areas-comuns/     ← 50 imagens, uma sub-categoria por ambiente
    ├── plantas/          ← 2 tipologias + planta de lazer, fundo branco
    ├── miniaturas/       ← espelha fachada/, areas-comuns/ e plantas/ (grade)
    └── video/            ← vídeo 1080p (gitignored; ainda não entregue)
```

> Pastas e arquivos publicados: **minúsculos, sem espaços e sem acentos** (o S3 é
> case-sensitive). Os nomes de exibição, com acentuação, ficam em `GALLERY_CONFIG`
> no `index.html`.

---

## Categorias

| Categoria | Sub-categorias |
|-----------|----------------|
| Fachada | — (Fachada × 3 · Acesso × 3) |
| Áreas Comuns | Salão de Festas · Espaço Gourmet · Academia · Alongamento · Spa · Sala de Jogos · Game Zone · Coworking · Mini Mercado · Lavanderia · Brinquedoteca · Playground · Espaço Pet |
| Plantas | Tipologias (2 e 3 quartos) · Área de Lazer |

---

## Assets — do material entregue ao WebP

| Uso | Tamanho | Qualidade |
|-----|---------|-----------|
| Lightbox | lado maior ≤ 2600 px (plantas ≤ 3000 px) | q80 (plantas q86) |
| Grade (`miniaturas/`) | lado maior ≤ 900 px (plantas ≤ 1400 px) | q72 (plantas q78) |

**Plantas:** os JPGs vêm com fundo preto, removido por **flood fill a partir dos
cantos** (só o preto conectado à borda vira branco) e recortado na própria caixa.

**Marca:** os SVGs do design vêm com as animações em `infinite`; o build troca para
`1 both` (tocam uma vez e congelam no quadro final) e encosta o viewBox do logo no
desenho (`23 82 555 437`). No logo do Trend o estado-base (sem animação) fica
desmontado, então `prefers-reduced-motion` só encurta a animação para ~0 ms em vez
de desligá-la.

```powershell
./build_assets.ps1            # só o que falta
./build_assets.ps1 -Force     # tudo
./build_assets.ps1 -Brand     # logo + fundo
./build_assets.ps1 -Video     # vídeo
```

Para acrescentar imagens: jogue o arquivo em `_originais/`, adicione a linha no TSV,
rode o script e registre o item em `GALLERY_CONFIG.items`.

**Tipografia:** Montserrat (Google Fonts).

---

## Pendências

- **Vídeo:** não foi entregue. O `video-gallery.html` aponta para
  `assets/video/video-trend.mp4`; o botão de vídeo no 3DVista só deve ser
  ligado depois de subir o arquivo (`./deploy.ps1 -WithVideo`).
- **Áreas (m²) das plantas:** não constam nas imagens; as notas das tipologias
  estão genéricas (“Suíte e dormitório”, “Suíte e 2 dormitórios”). Atualizar
  em `GALLERY_CONFIG` com os dados do book.
- **Sobras do template anterior** no disco, fora do deploy: `assets/thumbs/` e
  `fachada-interativa.html` (Aflora Marista). Podem ser apagadas.

---

## Deploy AWS S3

```powershell
./deploy.ps1               # sync (sem o vídeo) + cache-control no HTML/JS
./deploy.ps1 -QuickHtml    # só HTML/JS
./deploy.ps1 -WithVideo    # inclui o vídeo — 1ª vez / ao trocá-lo
```

O sync sobe **apenas** o que a galeria consome (HTML/JS + `assets/brand`, `fachada`,
`areas-comuns`, `plantas`, `miniaturas`, `video`). HTML/JS recebem
`no-cache,no-store,must-revalidate`.

---

## Integração 3DVista

Loader no JavaScript global do projeto e chamadas nos botões — trechos prontos em
`3dvista-snippets.md`:

```js
GaleriaImagens(1);      // abre galeria de imagens   · GaleriaImagens(0) fecha
GaleriaPlantas(1);      // abre galeria de plantas    · GaleriaPlantas(0) fecha
AbrirGaleriaVideos(1);  // abre o vídeo               · AbrirGaleriaVideos(0) fecha
```
