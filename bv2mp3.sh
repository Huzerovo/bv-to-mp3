#!/usr/bin/bash

export LANG='C'

BROWSER="firefox"
BV=""
BROWSER_FLAG="--cookies-from-browser"
BILI_URL="https://www.bilibili.com/video/"
YT_FLAGS=("--extract-audio" "--audio-format" "mp3" "--audio-quality" "0")
TRASH_DIR="$HOME/Public/tmp"

FLAG_REMOVE=0

MP3_TITLE=""
MP3_SINGER=""
MP3_COVER=""

get_cover() {
  if ! has_wget; then
    return
  fi
  local tdir
  tdir="$(mktemp -d)"
  wget "https://www.bilibili.com/video/$BV" --quiet -O "$tdir/$BV.html.gz"
  gzip -d "$tdir/$BV.html.gz"
  local cover
  cover="https:$(grep -o -P -e '<meta.*?>' "$tdir/$BV.html" \
    | grep -P -e 'og:image' \
    | grep -o -P -e 'content=".*?"' \
    | grep -o -P -e '[a-zA-Z0-9./]*@' \
    | grep -o -P -e '[a-zA-Z0-9./]*')"
  local filetype
  filetype="${cover##*.}"
  wget --quiet -O "$tdir/cover.$filetype" "$cover" || warn "Failed to get cover image"
  if [[ -f "$tdir/cover.$filetype" ]]; then
    MP3_COVER="$tdir/cover.$filetype"
  fi
}

info() {
  printf "\033[;32m%s\033[0m\n" "$@"
}

warn() {
  printf "\033[;33m%s\033[0m\n" "$@"
}

erro() {
  printf "\033[;31m%s\033[0m\n" "$@" 1>&2
}

die() {
  erro "$@"
  exit 1
}

usage() {
  cat << __EOF__
Usage: ${0##*/} [options] <BV>

    <BV>: bilibili BV number for video

Options:
    -h, --help,                         Show this help
    -r, --remove                        Remove all tags before write
    -b, --browser <firefox | chromium>  The name of the browser to load cookies from.
    -t, --title                         Specifies the music title
    -s, --singer                        Specifies the music singer
    -p, --picture <file>                Set the picture as cover
__EOF__
}

has_id3tag() {
  if ! which id3tag &> /dev/null; then
    warn "id3tag is required for edit ID3v1 tag"
    return 1
  fi
  return 0
}

has_musictag() {
  if ! which musictag &> /dev/null; then
    warn "musictag is required for edit ID3v2 tag"
    return 1
  fi
  return 0
}

has_wget() {
  if ! which wget &> /dev/null; then
    warn "wget is required for get bilibili video cover"
    return 1
  fi
  return 0
}

main() {
  if [[ ! -d "$TRASH_DIR" ]]; then
    mkdir -p "$TRASH_DIR" || die "mkdir failed"
  fi
  FILE_MP3="$BV.mp3"

  yt-dlp "${YT_FLAGS[@]}" -o "$FILE_MP3" -- "$BILI_URL$BV" || die "download $BV failed"

  if [[ $FLAG_REMOVE -eq 1 ]]; then
    musictag --remove "$FILE_MP3"
  fi

  if has_id3tag; then
    id3tag --v1tag --comment="$BV" "$FILE_MP3" || warn "id3tag: add comment failed"
  fi
  if has_musictag; then
    musictag --comment "$BV" "$FILE_MP3" || warn "musictag: add comment failed"
  fi

  if [[ "$MP3_SINGER" != "" && "$MP3_TITLE" != "" ]]; then
    if has_id3tag; then
      id3tag --v1tag --song="$MP3_TITLE" \
        --artist "$MP3_SINGER" \
        "$FILE_MP3" || warn "id3tag: add title and singer failed"
    fi
    if has_musictag; then
      musictag --artist "$MP3_SINGER" --title "$MP3_TITLE" "$FILE_MP3"
      if [[ -n "$MP3_COVER" ]] && [[ -f "$MP3_COVER" ]]; then
        musictag --image "$MP3_COVER" "$FILE_MP3"
      fi
    fi
  fi
  mv "$FILE_MP3" "$MP3_TITLE - ${MP3_SINGER}.mp3"
}

if [[ "$1" == "" ]]; then
  usage
  exit 1
fi

if [[ $# -eq 1 ]]; then
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    *) ;;

  esac
fi

while [[ $# -gt 1 ]]; do
  case $1 in
    -h | --help)
      usage
      exit 0
      ;;
    -b | --browser)
      shift
      BROWSER=$1
      info "Use cookies from browswer ${BROWSER}"
      YT_FLAGS=("$BROWSER_FLAG" "$BROWSER" "${YT_FLAGS[@]}")
      ;;
    -r | --remove)
      FLAG_REMOVE=1
      ;;
    -t | --title)
      shift
      MP3_TITLE="$1"
      ;;
    -s | --singer)
      shift
      MP3_SINGER="$1"
      ;;
    -p | --picture)
      shift
      MP3_COVER="$1"
      ;;
    *)
      die "unknow option: $1"
      ;;
  esac
  shift
done

BV="$1"

if [[ -z "$MP3_TITLE" || -z "$MP3_SINGER" ]]; then
  warn "You have batter set the title and singer for mp3 file."
fi

if [[ -z "$BV" ]]; then
  die "Need BV number"
fi

if [[ -z "$MP3_COVER" ]]; then
  get_cover
fi
main
exit 0

# vim: sts=2 ts=2 sw=2
