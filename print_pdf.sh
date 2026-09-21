#!/bin/bash
# Print the course website to PDF.
#
# Usage: ./print_pdf.sh [page ...]
#   ./print_pdf.sh                      -> syllabus.pdf (index page only)
#   ./print_pdf.sh index session1 ...   -> website.pdf (pages merged in order)
#
# Builds the site with Franklin (no prepath), serves __site locally,
# and prints each page with headless Chrome.

set -e
cd "$(dirname "$0")"

PORT=8765
CHROME=$(command -v google-chrome || command -v google-chrome-stable || command -v chromium || command -v chromium-browser)
[ -n "$CHROME" ] || { echo "Chrome/Chromium not found"; exit 1; }

pages=("$@")
if [ ${#pages[@]} -eq 0 ]; then
  pages=(index)
  out=syllabus.pdf
else
  out=website.pdf
fi

julia --startup-file=no -e 'using Franklin; optimize(prerender=false, minify=false)'

# Serve under /cee200/ to match the prepath used on GitHub Pages
tmp=$(mktemp -d)
ln -s "$PWD/__site" "$tmp/cee200"
python3 -m http.server $PORT --directory "$tmp" >/dev/null 2>&1 &
server=$!
trap 'kill $server 2>/dev/null; rm -rf "$tmp"' EXIT
sleep 1

files=()
for p in "${pages[@]}"; do
  if [ "$p" = index ]; then url="http://localhost:$PORT/cee200/"; else url="http://localhost:$PORT/cee200/$p/"; fi
  f="$tmp/page_$p.pdf"
  echo "Printing $url"
  "$CHROME" --headless=new --disable-gpu --no-pdf-header-footer \
    --virtual-time-budget=10000 --print-to-pdf="$f" "$url" 2>/dev/null
  files+=("$f")
done

if [ ${#files[@]} -eq 1 ]; then
  cp "${files[0]}" "$out"
else
  pdfunite "${files[@]}" "$out"
fi
echo "Wrote $out"
