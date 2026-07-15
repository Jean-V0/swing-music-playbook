#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Uso:
  utils.sh tag-mp3 --file ARQUIVO.mp3 --album ALBUM [opções]

Opções:
  --cover CAMINHO_O_URL  Imagem de capa (JPG, PNG, WebP ou URL HTTPS).
  --title TITULO         Atualiza o título da faixa.
  --artist ARTISTA       Atualiza o artista.
  --album-artist ARTISTA Atualiza o artista do álbum.
  --no-backup            Não cria o backup <arquivo>.mp3.bak.
  -h, --help             Mostra esta ajuda.

Exemplo:
  ./utils.sh tag-mp3 \
    --file '/opt/musics/Minha Musica.mp3' \
    --album 'Meu Album' \
    --cover 'https://exemplo.com/capa.jpg' \
    --artist 'Artista'

O áudio não é recodificado. Com capa, o arquivo recebe uma imagem embutida
("attached picture") compatível com players de MP3.
EOF
}

die() {
  echo "Erro: $*" >&2
  exit 1
}

need_command() {
  command -v "$1" >/dev/null 2>&1 || die "'$1' não está instalado ou não está no PATH."
}

is_url() {
  [[ "$1" =~ ^https?:// ]]
}

tag_mp3() {
  local input=""
  local album=""
  local cover=""
  local title=""
  local artist=""
  local album_artist=""
  local backup=true

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --file) input="${2:-}"; shift 2 ;;
      --album) album="${2:-}"; shift 2 ;;
      --cover) cover="${2:-}"; shift 2 ;;
      --title) title="${2:-}"; shift 2 ;;
      --artist) artist="${2:-}"; shift 2 ;;
      --album-artist) album_artist="${2:-}"; shift 2 ;;
      --no-backup) backup=false; shift ;;
      -h|--help) usage; return 0 ;;
      *) die "Opção desconhecida: $1" ;;
    esac
  done

  [[ -n "$input" ]] || die "Informe --file."
  [[ -f "$input" ]] || die "Arquivo não encontrado: $input"
  [[ "${input,,}" == *.mp3 ]] || die "O arquivo precisa ter extensão .mp3."
  [[ -n "$album" ]] || die "Informe --album."

  need_command ffmpeg

  local directory base temp_base output cover_file="" backup_file
  directory="$(cd "$(dirname "$input")" && pwd)"
  base="$(basename "$input")"
  temp_base="$(mktemp "$directory/.${base}.metadata.XXXXXX")"
  output="${temp_base}.mp3"
  rm -f "$temp_base"

  cleanup() {
    rm -f "$output"
    [[ -z "$cover_file" || "$cover_file" == "$cover" ]] || rm -f "$cover_file"
  }
  trap cleanup RETURN

  local -a ffmpeg_args=(
    -hide_banner -loglevel error -y
    -i "$input"
  )

  if [[ -n "$cover" ]]; then
    if is_url "$cover"; then
      need_command curl
      cover_file="$(mktemp /tmp/swingmusic-cover.XXXXXX)"
      curl --fail --location --silent --show-error "$cover" -o "$cover_file"
    else
      [[ -f "$cover" ]] || die "Imagem de capa não encontrada: $cover"
      cover_file="$cover"
    fi

    ffmpeg_args+=(
      -i "$cover_file"
      -map 0:a:0 -map 1:v:0
      -c:a copy -c:v mjpeg
      -disposition:v:0 attached_pic
      -metadata:s:v:0 title="Album cover"
      -metadata:s:v:0 comment="Cover (front)"
    )
  else
    # Mantém streams existentes, incluindo uma capa já embutida.
    ffmpeg_args+=( -map 0 -c copy )
  fi

  ffmpeg_args+=(
    -map_metadata 0
    -id3v2_version 3
    -metadata album="$album"
  )
  [[ -z "$title" ]] || ffmpeg_args+=( -metadata title="$title" )
  [[ -z "$artist" ]] || ffmpeg_args+=( -metadata artist="$artist" )
  [[ -z "$album_artist" ]] || ffmpeg_args+=( -metadata album_artist="$album_artist" )
  ffmpeg_args+=( "$output" )

  ffmpeg "${ffmpeg_args[@]}"

  if [[ "$backup" == true ]]; then
    backup_file="${input}.bak"
    [[ ! -e "$backup_file" ]] || die "Backup já existe: $backup_file (mova ou apague antes de continuar)."
    cp -p "$input" "$backup_file"
  fi

  mv -f "$output" "$input"
  trap - RETURN
  [[ -z "$cover_file" || "$cover_file" == "$cover" ]] || rm -f "$cover_file"

  echo "Metadados atualizados: $input"
  [[ "$backup" == true ]] && echo "Backup criado: ${input}.bak"
}

main() {
  case "${1:-}" in
    tag-mp3) shift; tag_mp3 "$@" ;;
    -h|--help|"") usage ;;
    *) die "Comando desconhecido: $1" ;;
  esac
}

main "$@"
