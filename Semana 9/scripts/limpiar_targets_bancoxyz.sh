#!/usr/bin/env bash
# BancoXYZ S9 - Limpieza idempotente de directorios Maven target/.
# Solo elimina directorios llamados target/ cuyo padre contiene pom.xml.
# No borra CSV, SQL, bases de datos, volumenes, ZIP ni otras carpetas.
set -Eeuo pipefail

usage() {
  printf 'Uso: bash %s [--dry-run] [RUTA_PROYECTO]\n' "$(basename "$0")"
}

dry_run=0
root_arg=''
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'ERROR: opcion no reconocida: %s\n' "$arg" >&2; usage; exit 2 ;;
    *) if [[ -n "$root_arg" ]]; then printf 'ERROR: indica una sola ruta.\n' >&2; exit 2; fi; root_arg="$arg" ;;
  esac
done

if [[ -n "$root_arg" ]]; then
  root="$(cd -- "$root_arg" 2>/dev/null && pwd -P)" || { echo 'ERROR: ruta invalida.' >&2; exit 2; }
elif [[ -d './Semana 9' ]]; then
  root="$(pwd -P)"
else
  # Permite ejecutarlo desde otro directorio tras instalarlo en Semana 9/scripts/.
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
  root="$(cd -- "$script_dir/../.." && pwd -P)" || exit 2
fi

if [[ ! -d "$root/Semana 9" ]]; then
  echo 'ERROR: no se encontro "Semana 9". Ejecuta desde la raiz de bancoxyzbatch o pasa esa ruta.' >&2
  exit 2
fi

printf '%s\n' "Proyecto: $root" "Modo: $([[ $dry_run -eq 1 ]] && echo 'simulacion' || echo 'eliminacion de target/')"
count=0
# -P (predeterminado): no sigue enlaces simbolicos. Se omiten .git y node_modules.
while IFS= read -r -d '' candidate; do
  parent="$(dirname -- "$candidate")"
  # Solo directorios de compilacion Maven; no toca otras carpetas llamadas target.
  [[ -f "$parent/pom.xml" ]] || continue
  [[ ! -L "$candidate" ]] || continue
  if [[ $dry_run -eq 1 ]]; then
    printf 'ENCONTRADO: %s\n' "$candidate"
  else
    rm -rf -- "$candidate"
    printf 'ELIMINADO: %s\n' "$candidate"
  fi
  ((count+=1))
done < <(find "$root/Semana 9" \( -type d \( -name .git -o -name node_modules \) -prune \) -o \( -type d -name target -prune -print0 \))

if [[ $count -eq 0 ]]; then
  echo 'OK: no hay carpetas Maven target/ que limpiar.'
elif [[ $dry_run -eq 1 ]]; then
  printf 'OK: %d carpetas target/ encontradas. No se elimino nada.\n' "$count"
else
  printf 'OK: %d carpetas target/ eliminadas. Solo se limpiaron compilados Maven.\n' "$count"
fi
