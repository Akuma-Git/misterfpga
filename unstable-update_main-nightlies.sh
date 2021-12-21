#!/bin/sh
version=0.00
#
#  MiSTer-unstable-nightlies Updater (c) 2021 by Akuma GPLv2
#
#  20211221 initial release
#
self="$(readlink -f "$0")"

trap "result" 0 1 3 15

result(){
  case "$?" in
    0) echo "MiSTer version: ${nightliesurl##*/}";;
   99) echo "self: updated self";;
  100) echo "error: cannot reach url";;
  101) echo "error: cannot write to sdcard";;
  102) echo "error: download failed";;
  103) echo "error: checksum failed";;
  104) echo "MiSTer version: already up to date";;
  esac
}

makedir(){ [ -d "$1" ] || { mkdir -p "$1" || exit 101;};}
download(){ wget --no-cache -q "$2" -O "$1" || { rm "$1";exit 102;};}
urlcat(){ wget --no-cache -q "$1" -O - || exit 100;}
checksum(){ md5sum "$1"|grep -q "$2" || { rm "$1";exit 103;};}

selfurl="https://raw.githubusercontent.com/Akuma-Git/misterfpga/main/unstable-update_main-nightlies.sh"
selfurl_version="$(urlcat "$selfurl"|sed -n 's,^version=,,;2p')"

[ "$selfurl_version" = "$version" ] || {
  tempfile="$(mktemp -u)"; download "$tempfile" "$selfurl"
  mv "$tempfile" "$self";chmod +x "$self";exec "$self"; exit 99
}

nightliesurl="https://github.com/MiSTer-unstable-nightlies/Main_MiSTer/releases/tag/unstable-builds"
nightliesfile="$(wget -q $nightliesurl -O -|grep -oE 'MiSTer_unstable_[0-9]{8}_[0-9a-f]{4}'|tail -1)"
[ -n "$nightliesfile" ] || exit 101

nightliesurl="https://github.com/MiSTer-unstable-nightlies/Main_MiSTer/releases/download/unstable-builds/${nightliesfile}"
nightliessize="$(wget --spider "$nightliesurl" 2>&1|grep ^Length|cut -d' ' -f2)"
[ -n "$nightliessize" ] || exit 101

misterfile="/media/fat/MiSTer"
mistersize="$(stat -c%s "$misterfile")"
[ "$nightliessize" = "$mistersize" ] && exit 104

tempfile="$(mktemp -u)"
download "$tempfile" "$nightliesurl"
tempsize="$(stat -c%s "$tempfile")"
[ "$nightliessize" = "$tempsize" ] || exit 102

mv -f "${misterfile}" "${misterfile}.bak"
mv -f "${tempfile}" "$misterfile"
chmod +x "$misterfile"

exit 0
