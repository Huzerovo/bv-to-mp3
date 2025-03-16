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

die() {
  echo "==="
  echo "$@"
  exit 1
}

usage() {
  cat << __EOF__
    Usage:
    ${0##*/} [options] <BV>

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

has_musictag() {
  if ! which musictag; then
    echo "Required musictag"
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

  id3tag --v1tag --comment "$BV" "$FILE_MP3" || echo "id3tag: add comment failed"
  if has_musictag; then
    musictag --comment "$BV" "$FILE_MP3" || echo "musictag: add comment failed"
  fi

  if [[ "$MP3_SINGER" != "" && "$MP3_TITLE" != "" ]]; then
    id3tag --v1tag --song "$MP3_TITLE" \
      --artist "$MP3_SINGER" \
      "$FILE_MP3" || echo "add title and singer failed"
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
      echo "Use cookies from browswer ${BROWSER}"
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
      echo "unknow option: $1"
      exit 2
      ;;
  esac
  shift
done

BV="$1"

if [[ -z "$MP3_TITLE" || -z "$MP3_SINGER" ]]; then
  echo "======================================================"
  echo "You have batter set the title and singer for mp3 file."
  echo "======================================================"
fi

if [[ -n "$BV" ]]; then
  main
fi

exit 0

# vim: sts=2 ts=2 sw=2
