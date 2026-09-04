#!/usr/bin/env bash
# Audita la "firma Abanimal" en una lista de sitios: idioma, meta, H1, alt, schema, peso.
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36"
OUT=/tmp/audit_out
mkdir -p $OUT

for url in "$@"; do
  host=$(echo "$url" | sed -E 's#https?://##; s#/.*##')
  f="$OUT/$host.html"
  code=$(curl -sL --max-time 30 -A "$UA" -w '%{http_code}' "$url" -o "$f")
  size=$(wc -c < "$f" 2>/dev/null || echo 0)
  lang=$(grep -oim1 '<html[^>]*lang="[^"]*"' "$f" | grep -oi 'lang="[^"]*"' | head -1)
  oglocale=$(grep -oim1 'og:locale"[^>]*content="[^"]*"' "$f" | grep -o 'content="[^"]*"' | head -1)
  desc=$(grep -oicm1 'name="description"' "$f")
  h1=$(grep -oic '<h1' "$f")
  imgs=$(grep -oic '<img' "$f")
  altv=$(grep -oic 'alt=""' "$f")
  noalt=$(python3 - "$f" <<'PY'
import sys,re
h=open(sys.argv[1],encoding='utf8',errors='ignore').read()
tags=re.findall(r'<img\b[^>]*>',h,re.I)
sin=sum(1 for t in tags if not re.search(r'alt="[^"]+"',t,re.I))
print(f"{sin}/{len(tags)}")
PY
)
  types=$(grep -o '"@type": *"[^"]*"' "$f" | sed 's/.*"@type": *"//; s/"//' | sort -u | tr '\n' ',' )
  types2=$(grep -o '"@type":"[^"]*"' "$f" | sed 's/.*"@type":"//; s/"//' | sort -u | tr '\n' ',')
  wp=$(grep -oim1 'WordPress [0-9.]*' "$f" | head -1)
  elem=$(grep -oim1 'elementor[^"]*ver=[0-9.]*' "$f" | grep -o 'ver=[0-9.]*' | head -1)
  yoast=$(grep -oim1 'Yoast SEO v[0-9.]*' "$f" | head -1)
  wa=$(grep -oic 'wa.me\|api.whatsapp' "$f")
  words=$(python3 - "$f" <<'PY'
import sys,re
h=open(sys.argv[1],encoding='utf8',errors='ignore').read()
h=re.sub(r'(?is)<(script|style|noscript).*?</\1>',' ',h)
t=re.sub(r'(?s)<[^>]+>',' ',h)
t=re.sub(r'&[a-z#0-9]+;',' ',t)
print(len([w for w in t.split() if len(w)>1]))
PY
)
  echo "=== $host  [HTTP $code, ${size}B]"
  echo "    lang=${lang:-NINGUNO} | og:locale=${oglocale:-no} | meta-desc=$desc | H1=$h1 | palabras=$words"
  echo "    img sin alt: $noalt | alt vacio: $altv | whatsapp-links: $wa"
  echo "    schema: ${types}${types2}"
  echo "    stack: ${wp:-?} ${elem:+Elementor $elem} ${yoast:-}"
done
