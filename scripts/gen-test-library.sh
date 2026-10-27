#!/bin/sh
# Generates the synthetic test library into /music. Runs inside the
# deluan/navidrome image (its ffmpeg has libmp3lame and libopus).
set -e
cd /music
mk(){ d="$1"; f="$2"; fmt=$3; fr=$4; du=$5; shift 5; mkdir -p "$d"
  a="$1"; aa="$2"; al="$3"; ti="$4"; tr="$5"; ge="$6"; da="$7"; shift 7
  ffmpeg -loglevel error -y -f lavfi -i "sine=frequency=$fr:duration=$du" -ac 2 "$@" \
    -metadata artist="$a" -metadata album_artist="$aa" -metadata album="$al" -metadata title="$ti" \
    -metadata track="$tr" -metadata genre="$ge" -metadata date="$da" "$d/$f.$fmt"; }
for t in 1 2 3 4 5 6; do mk "Test Artist/Electro Album" "0$t - Electro $t" flac $((200+t*40)) 40 "Test Artist" "Test Artist" "Electro Album" "Electro $t" $t "Electronic" 2021; done
for t in 1 2 3 4; do mk "Test Artist/Rock Album" "0$t - Rock $t" mp3 $((300+t*30)) 35 "Test Artist" "Test Artist" "Rock Album" "Rock $t" $t "Rock" 2019 -c:a libmp3lame -b:a 192k; done
for t in 1 2 3; do mk "Группа Кино/Звезда" "0$t - Песня $t" mp3 $((440+t*20)) 30 "Группа Кино" "Группа Кино" "Звезда по имени Солнце" "Песня №$t" $t "Рок" 1989 -c:a libmp3lame; done
for t in 1 2; do mk "日本のアーティスト/アルバム" "0$t - 曲 $t" opus $((500+t*25)) 30 "日本のアーティスト" "日本のアーティスト" "アルバム 🎵" "曲 $t" $t "J-Pop" 2020 -c:a libopus; done
for t in 1 2 3; do mk "Various Artists/Compilation" "0$t - Comp $t" m4a $((350+t*15)) 30 "Artist $t feat. Someone" "Various Artists" "Compilation & <Specials> \"Quotes\"" "Track's \"$t\" & more" $t "Pop" 2022 -c:a aac; done
for t in 1 2; do mk "Ogg Artist/Vorbis Album" "0$t - Vorb $t" ogg $((700+t*10)) 30 "Ogg Artist" "Ogg Artist" "Vorbis Album" "Vorb $t" $t "Jazz" 2018 -c:a libvorbis; done
mk "Edge Cases" "no tags" mp3 600 20 "" "" "" "" "" "" "" -c:a libmp3lame
mk "Edge Cases" "very long" flac 610 20 "Artist With An Extremely Long Name That Goes On And On For Testing Ellipsis Handling In Lists" "" "Album Title That Is Also Unreasonably Long To See How The UI Truncates It Properly" "Title xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" 1 "Ambient" 2000
mk "Edge Cases" "short 1s" mp3 620 1 "Short Artist" "" "Shorts" "One Second" 1 "Noise" 2001 -c:a libmp3lame
mk "Edge Cases" "long 9min" mp3 630 540 "Long Artist" "" "Longs" "Nine Minutes" 1 "Ambient" 2002 -c:a libmp3lame -b:a 96k
mk "Edge Cases" "hires 96k" flac 640 20 "HiRes Artist" "" "HiRes" "96kHz 24bit" 1 "Classical" 2023 -ar 96000 -sample_fmt s32
mkdir -p "Weird ;&'#% Dir"; cp "Edge Cases/short 1s.mp3" "Weird ;&'#% Dir/file with #hash ?.mp3"
mkdir -p "Delete Me"; for t in 1 2 3; do mk "Delete Me" "0$t - Deletable $t" mp3 $((800+t*10)) 15 "Deletable Artist" "Deletable Artist" "Disposable Album" "Deletable $t" $t "Test" 2024 -c:a libmp3lame; done
find . -type f | wc -l
