# Visuels de la boutique Roblox

| Fichier | Usage | Format imposé par Roblox |
|---|---|---|
| `icon-512.png` | Icône de l'expérience | 512×512, PNG/JPG |
| `thumbnail-1920x1080.png` | Vignette (jusqu'à 10 par jeu) | 1920×1080, 16:9 |

Les `.svg` sont les sources, éditables au texte. Pour re-générer les PNG :

```bash
npm install @resvg/resvg-js
node -e 'const{Resvg}=require("@resvg/resvg-js"),fs=require("fs");
const r=new Resvg(fs.readFileSync("assets/icon.svg","utf8"),
  {fitTo:{mode:"width",value:512},font:{loadSystemFonts:true}});
fs.writeFileSync("assets/icon-512.png",r.render().asPng())'
```

Police utilisée : DejaVu Sans Bold (présente sur la machine). Les couleurs du
maillot reprennent `Config.Jersey` — bleu nuit, bande rouge, liseré blanc, sans
nom de club ni écusson.

L'icône et la vignette s'envoient **à la main** depuis le Creator Hub : il
n'existe pas d'API Open Cloud pour définir l'icône d'une expérience.
