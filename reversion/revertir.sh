#!/usr/bin/env bash
# Deshace las migraciones desde la más nueva hasta la versión indicada (incluida), en orden inverso, cada una en su
# transacción. Uso: DATABASE_URL=... ./reversion/revertir.sh 39
# Solo para revertir una versión del backend que ya no se va a usar: borra los datos de esas tablas. Haz antes el
# respaldo de docs/respaldo.md. Pide confirmación salvo con --si.
set -euo pipefail
: "${DATABASE_URL:?Define DATABASE_URL}"
cd "$(dirname "$0")"
desde="${1:?Indica la primera versión a deshacer, por ejemplo 39}"
confirmar="${2:-}"
scripts=$(ls U*__*.sql | sort -t_ -k1.2 -n -r | awk -F'__' -v d="$desde" '{v=substr($1,2)+0; if (v>=d) print}')
[ -n "$scripts" ] || { echo "No hay reversiones desde la versión $desde."; exit 0; }
echo "Se deshará, en este orden:"; echo "$scripts"
if [ "$confirmar" != "--si" ]; then
  read -r -p "Esto borra los datos de esas tablas. Escribe SI para seguir: " ok
  [ "$ok" = "SI" ] || { echo "Cancelado."; exit 1; }
fi
for script in $scripts; do
  echo "Deshaciendo $script"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f "$script"
done
