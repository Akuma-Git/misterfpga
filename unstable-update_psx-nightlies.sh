#!/bin/sh
version=0.10
#
#  MiSTer-unstable-nightlies Updater (c) 2021 by Akuma GPLv2
#
#  20220612 update: added softlink to latest nightly core " PSX_latest"
#  20220612 update: replaced bios url
#  20220612 update: replaced bios update routine
#  20220612 update: added unpack routine
#  20220207 update: added main update notice
#  20220207 update: removed one-time main update
#  20220130 update: added github commit check
#  20211222 update: changed update exit code to 99, removed white lines
#  20211221 update: added auto-rename if old PlayStation games folder is found
#  20211221 update: added one-time run for unstable-update_main-nightlies.sh
#  20211221 update: added exit to urlcat as extra safety measure
#  20211219 update: fixed upstream rename of PlayStation core to PSX
#  20211219 update: added self-update
#  20211219 update: moved maxkeep=N into self.ini
#  20211218 update: added maxkeep=N, keep max N nightlies
#  20211213 update: using new source, json file from @theypsilon
#  20211212 update: corrected bios download directory
#
corename="PSX"
oldcorename="PlayStation"

self="$(readlink -f "$0")"

conf="${self%.*}.ini"
[ -f "$conf" ] && . "$conf"

trap "result" 0 1 3 15

result(){
  case "$?" in
    0) echo -e "last version: Github says, last commit on $gitversion"
       echo -e "core version: ${corefile##*/}\n";;
   99) echo "self: updated self";;
  100) echo "error: cannot reach url";;
  101) echo "error: cannot write to sdcard";;
  102) echo "error: download failed";;
  103) echo "error: checksum failed";;
  104) echo "error: json parsing failed";;
  105) echo "error: unzip failed";;
  esac
}

makedir(){ [ -d "$1" ] || { mkdir -p "$1" || exit 101;};}
download(){ wget --no-cache -q "$2" -O "$1" || { rm "$1";exit 102;};}
urlcat(){ wget --no-cache -q "$1" -O - || exit 100;}
checksum(){ md5sum "$1"|grep -q "$2" || { rm "$1";exit 103;};}
unpack(){ unzip -o "$1" -d "$2" >/dev/null 2>&1 || exit 105;}

selfurl="https://raw.githubusercontent.com/Akuma-Git/misterfpga/main/unstable-update_psx-nightlies.sh"
selfurl_version="$(urlcat "$selfurl"|sed -n 's,^version=,,;2p')"

[ "$selfurl_version" = "$version" ] || {
  tempfile="$(mktemp -u)"; download "$tempfile" "$selfurl"
  mv "$tempfile" "$self";chmod +x "$self";exec "$self"; exit 99
}

coredir="/media/fat/_Unstable";makedir "$coredir"
gamesdir="/media/fat/games"
psxdir="$gamesdir/${corename}";makedir "$psxdir"
biosdir="$psxdir/.bios";makedir "$biosdir"

biosurl="https://archive.org/download/2019_11_25_redump_bios/Redump-BIOS/Sony%20-%20PlayStation%20-%20BIOS%20%2824%29%20%282016-10-21%29.zip"
bioshash="660c547dac49dcb87f6a2633af1fa1a1"
biosfile="$psxdir/psxbios.zip"
[ -f "$biosfile" ] || download "$biosfile" "$biosurl"
[ -n "$bioshash" ] && checksum "$biosfile" "$bioshash"

[ -f "$psxdir/boot.rom" -a -L "$psxdir/boot.rom" -a \
  -f "$psxdir/boot1.rom" -a -L "$psxdir/boot1.rom" -a \
  -f "$psxdir/boot2.rom" -a -L "$psxdir/boot2.rom" ] || {
  unpack "$psxdir/psxbios.zip" "$biosdir"
  unpack "$biosdir/*.zip" "$biosdir"
  rm "$biosdir"/ps*.zip
  echo "bios updated:"
  ln -vsf "$biosdir/ps-41a.bin" "$psxdir/boot.rom"
  ln -vsf "$biosdir/ps-40j.bin" "$psxdir/boot1.rom"
  ln -vsf "$biosdir/ps-41e.bin" "$psxdir/boot2.rom"
}

nightliesurl="https://raw.githubusercontent.com/MiSTer-unstable-nightlies/Unstable_Folder_MiSTer/main/db_unstable_nightlies_folder.json"
nightlies="$(urlcat "$nightliesurl")" || exit 100
export $(echo $nightlies|grep -o "\"_Unstable/${corename}.[^}]*}"|sed 's,^.*{,,;s,},,;s,": ,=,g;s/,/\n/g;s,",,g')
[ -n "$url" -o -n "$hash" ] || exit 104

corefile="$coredir/${url##*/}"
[ -f "$corefile" ] || download "$corefile" "$url"
[ -f "$corefile" ] || checksum "$corefile" "$hash"
ln -sf "$corefile" "$coredir/ PSX_latest.rbf"

[ -d "${gamesdir}/${oldcorename}" ] && {
  echo "NOTICE: renaming directories with new core name:"
  find "/media/fat" -maxdepth 2 -type d -name "$oldcorename" -exec rename -v $oldcorename $corename {} \;
}

mainurl="https://raw.githubusercontent.com/Akuma-Git/misterfpga/main/unstable-update_main-nightlies.sh"
mainfile="/media/fat/Scripts/${mainurl##*/}"
[ -f "$mainfile" ] || download "$mainfile" "$mainurl"

#misterhash="05074084b1469c75648d7eb4f1fb2a7c"
#misterfile="/media/fat/MiSTer"
#md5sum "$misterfile"|grep -q "$misterhash" && echo -e "NOTICE: Please update MAIN with: \"${mainurl##*/}\"\n"

[ -n "$maxkeep" -a -n "$coredir" -a -n "$corename" ] \
  && { ls -t "${coredir}/${corename}_unstable_"*".rbf"|awk "NR>$maxkeep"|xargs -r rm;}

commiturl="https://github.com/MiSTer-unstable-nightlies/PSX_MiSTer/commits/main"
gitversion="$(urlcat "$commiturl"|grep "Commits on"|head -1|sed 's,^.*Commits on ,,;s,<.*$,,')"

exit 0
