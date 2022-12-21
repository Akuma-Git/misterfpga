#!/bin/sh -e
version=0.00
resize

LICENSE='
These scripts are part of the ScummVM Setup Utility (c) 2022 by Akuma
under a GPLv3 license.

ScummVM Setup Utility is free software: you can redistribute it
and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

ScummVM Setup Utility is distributed in the hope that it will be
useful, but WITHOUT ANY WARRANTY; without even the implied warranty
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with ScummVM Setup Utility. If not, see
<https:/www.gnu.org/licenses/>.
'

### messages
msg100="info: no internet connection."
msg101="info: user canceled"
msg102="info: fullscreen already disabled"
msg103="info: please install a ScummVM version first"
msg104="panic: contact developer, dont run this script again."
msg105="info: target does not exist"
msg106="info: could not find any configuration files."
msg107="error: cannot copy, source=target."
msg108="error: cannot reach url"
msg109="info: already on the latest version"

### sanity
[ ${DEBUG:-0} -eq 1 ] || {
	trap 'result' 0 1 3 15
	trap 'exit 101' 2
}

result(){
        local msg result=$? 
        case $result in
                  0) msg="info: user exit, bye!";;
		 99) msg="info: updated self";;
                101) msg="error $result: aborted by user";;
		111) msg="Rebooting...";reboot;;
        esac
	dialog --infobox "$msg" 3 40
        return $result
}

### Global variables
URL="https://github.com/bbond007/MiSTer_ScummVM"
CONF="/media/fat/MiSTer.ini"
APP="/media/fat/Apps/ScummVM"
PKG="$APP/packages"
LIB="$APP/lib"
SAVES="$APP/saves"
EXTRA="$APP/extra"

export HOME=/tmp
export LD_LIBRARY_PATH=$LIB:$LIB/pulseaudio
mkdir -p $APP $EXTRA $SAVES $SAVES-old

### Dialog Macros
dialog="dialog --keep-tite --keep-window --no-shadow"
msgbox="$dialog --msgbox"
programbox="$dialog --programbox 25 80"
infobox="dialog --keep-window --infobox"
yesno="$dialog --defaultno --yesno"
editbox="$dialog --editbox"

### Functions

get_version(){ echo $1 | sed 's/[0-9]/.&/g;s/^.//';}

show_menu(){ local IFS=$'|\n'; eval $dialog --no-tags --nook --nocancel --stdout --menu \$$1 25 80 76 \$$2;}

get_key(){ sed -n "/\[$1\]/,/\[/{/^$2=/p}" $3;}

get_keyval(){ sed -n "/\[$1\]/,/\[/{s/^$2=//;s/ ;.*$//p}" $3;}

exist_section(){ grep -q "\[$1\]" $2;}

add_section(){ echo "[$1]" >> $2;}

exist_key(){ [ ! -z "$(get_key $1 $2 $3)" ];}

add_key(){ sed -i "/\[$1\]/a $2=$3" $4;}

del_key(){ sed -i "/\[$1\]/,/\[/{/^$2=/d}" $3;}

set_keyval(){ sed -i "/\[$1\]/,/\[/{s/^$2=.*$/$2=$3/}" $4;}

get_local_size(){ [ -f "$1" ] && wc -c $1 | awk '{print $1}';}

get_remote_size(){ wget --spider $1 2>&1 | awk '/Length:/ awk {print $2}';}

online(){ nc -z github.com 443;}

urlcat(){ wget --no-cache -q "$1" -O -;}

get_blobs(){
	local raw="https://raw.githubusercontent.com"
	wget -q $1 -O - |\
	  awk -v raw=$raw -F'["]' '/blob/{gsub("/blob/","/") $10;print raw$10}' |\
	    sed 's,+, ,g;s,%,\\x,g' |\
	      xargs -0 printf "%b"
}

download(){
	mkdir -p $1
	for url in $(eval echo \$$2)
	do
		local filename="${url##*/}"
		local file="$1/$filename"
		local remote_sz=$(get_remote_size $url)
		local local_sz=$(get_local_size "$file")
		printf "$filename: "
		[ "$remote_sz" = "$local_sz" ] && echo OK || {
			echo GET
			wget -q $url -O "$file"
		}
	done
}

undeb(){
	mkdir -p $2
        local arc=$(ar t $1 data.tar.*)
        case $arc in *.gz) cat=zcat;; *.xz) cat=xzcat;;esac
        ar p $1 $arc | $cat | tar -xf - -C $2
}

download_scummvm(){ #1 choice #2 version
	echo -e "\n### Checking: ScummVM $(get_version $1)"
	local list=$(get_blobs $URL| grep "$1$")
	download $APP/$1 list
	local list=$(get_blobs $URL| grep "$2\.")
	download $APP/$1 list
}

download_engine(){ #1 choice #2 version
	echo -e "\n### Checking: Engine $(get_version $2)"
	local url="$URL/tree/master/engine-data/$2"
	local list=$(get_blobs $url | grep '\.dat')
	download $APP/$1 list
}

download_libraries(){
	echo -e "\n### Checking: ScummVM Library Packages"
	local url="$URL/tree/master/DEBS"
	local list=$(get_blobs $url | grep 'lib.*\.deb')
	mkdir -p $PKG
	download $PKG list
}

install_libraries(){
	echo -e "\n### Installing: ScummVM Libraries"
	local lib_tmp=$(mktemp -d)
	mkdir -p $LIB
	for file in $PKG/lib*.deb
	do
		printf "${file##*/}: "
		undeb $file $lib_tmp && echo OK || echo FAIL
	done
	cp -r $lib_tmp/usr/lib/arm-linux-gnueabihf/* $LIB
	cp -r $lib_tmp/lib/arm-linux-gnueabihf/* $LIB
	rm -rf $lib_tmp
}

list_versions(){ while read i;do echo "$i|ScummVM v$(get_version $i)";done;}

list_files(){ while read i;do echo "$i|$i";done;}

get_scale_factor(){
	case "$(get_keyval MENU video_mode $CONF)" in
		1600*) echo 5;;
		1280*) echo 4;;
		 960*) echo 3;;
		 640*) echo 2;;
		    *) echo 1;;
	esac
}

### menu options

TEXT_SETRES='Set video_mode:'
MENU_SETRES='
320,240|1x (240p)
640,480|2x (480p)
960,720|3x (720p)
1280,960|4x (1080p)
1600,1200|5x (1440p)
'
TEXT_REFRESH='Set refresh rate:'
MENU_REFRESH='
60|60hz (default)
50|50hz
'
TEXT_FULLSCREEN_INFO='
ScummVM can only run in fullscreen if the MiSTer "MENU core" video_mode
has been set to a multiple of 320x240.

Choose a resolution and refresh rate that best matches your setup.

Continue ?
'
TEXT_FULLSCREEN_ENABLE='
Apply these settings to "MiSTer.ini" and reboot ?

[MENU]
video_mode'

fullscreen_enable(){
	$yesno "$TEXT_FULLSCREEN_INFO" 10 80 || return 0
	[ -f "$CONF.scummvm" ] || cp -p $CONF $CONF.scummvm
	local setres="$(show_menu TEXT_SETRES MENU_SETRES)"
	[ -n "$setres" ] || return 0
	local refresh="$(show_menu TEXT_REFRESH MENU_REFRESH)"
	[ -n "$refresh" ] || return 0
	local tag="; Added by ScummVM Setup Utility"
	local choice="$setres,$refresh"
	$yesno "$TEXT_FULLSCREEN_ENABLE=$choice" 10 80 || return 0
	exist_section MENU $CONF || add_section MENU $CONF
	exist_key MENU video_mode $CONF \
		&& set_keyval MENU video_mode "$choice $tag" $CONF \
		|| add_key MENU video_mode "$choice $tag" $CONF
	exit 111
}

fullscreen_disable(){
	local key="$(get_key MENU video_mode $CONF)"
	[ -n "$key" ] || return 101
	local msg="Remove these settings from MiSTer.ini and reboot ?"
	$yesno "$msg\n\n[MENU]\n$key" 10 80 || return 0
	del_key MENU video_mode $CONF
	exit 111
}

scummvm_install(){
	online || return 100
	$infobox "Retrieving download list..." 3 80
	local list=$(for i in $(get_blobs $URL | sed -n 's,.*scummvm,,p')
			do echo "$i|ScummVM v$(get_version $i)";done | tac)
	local title='Choose a ScummVM version to install:'
	local choice=$(show_menu title list)
	[ -n "$choice" ] || return 0
	$yesno "Install ScummVM v$(get_version $choice) ?" 10 80 || return 0
	local version=${choice%-*}
	{
		download_scummvm $choice $version
		download_engine $choice $version
		download_libraries
		[ -n "$(find $LIB -type f -iname 'lib*')" ] || install_libraries
		echo "Done."
	} 2>&1 | $programbox
}

games_import(){
	local title="Select ScummVM version:"
	local list=$(ls -r $APP | grep ^[0-9] | list_versions)
	[ -n "$list" ] || return 103
	local version="$(show_menu title list)"
	[ -n "$version" ] || return 0
	local exe="$APP/$version/scummvm$version"
	local conf="$exe.ini"
	local title="Select game path:"
#	local list=$(find /media -mindepth 2 -maxdepth 3 -type d | sort | list_files)
	local list=$(find /media -mindepth 2 -maxdepth 3 -type d | grep -v '\.' | sort | list_files)
	local gamepath="$(show_menu title list)"
	[ -n "$gamepath" ] || return 0
	$exe --config=$conf --add --recursive --path=$gamepath 2>/dev/null | $programbox
}

saves_import(){
	local title="Select ScummVM version:"
	local list=$(ls -r $APP | grep ^[0-9] | list_versions)
	[ -n "$list" ] || return 103
	local version="$(show_menu title list)"
	[ -n "$version" ] || return 0
	[ ${version:0:2} -lt 26 ] \
		&& local target="$APP/saves-old" \
		|| local target="$APP/saves"
	mkdir -p "$target"
	$infobox "Searching for ScummVM 'saves' directory..." 3 80
	local title="Import ScummVM savegames from:"
	local list=$(find /media -type d -name 'saves*' | sort -r | list_files |grep -v $APP)
	[ -n "$list" ] || return 0
	local source="$(show_menu title list)"
	[ -n "$source" ] || return 0
	[ "$source" = "$target" ] && return 107
	$yesno "Copy savegame files from:\n\nsource = $source\ntarget = $target\n" 10 80 || return 0
	cp -rv $source/* $target 2>&1 | $programbox
}

scummvm_delete(){
	local title="Select ScummVM version:"
	local list=$(ls -r $APP | grep ^[0-9] | list_versions)
	[ -n "$list" ] || return 103
	local version="$(show_menu title list)"
	[ -n "$version" ] || return 0
	[ -n "$APP" ] || return 104
	target="${APP:---help }/${version:---help }"
	[ -d "$target" ] || return 105
	$yesno "Delete: ScummVM $(get_version $version)\n\ntarget = $target\n\n" 10 80 || return 0
	rm -rv "$target" 2>&1 | $programbox
}

library_update(){
	online || return 100
	$yesno "Do you want to update the ScummVM Linux Library Packages ?" 10 80 || return 0
	download_libraries 2>&1 | $programbox
}

library_install(){
	$yesno "Do you want to reinstall ScummVM Linux Libraries ?" 10 80 || return 0
	install_libraries 2>&1 | $programbox
}

config_import(){
	local title="Select ScummVM version:"
	local list=$(ls -r $APP | grep ^[0-9] | list_versions)
	[ -n "$list" ] || return 103
	local version="$(show_menu title list)"
	[ -n "$version" ] || return 0
	local target="$APP/$version/scummvm$version.ini"

	$infobox "Searching for ScummVM configuration files..." 3 80
	local title="Select source configuration file:"
	local list=$(find /media -iname 'scummvm*.ini' | sort -r | list_files)
	[ -n "$list" ] || return 106
	local source="$(show_menu title list)"
	[ -n "$source" ] || return 0

	[ "$source" = "$target" ] && return 107
	$yesno "Copy config:\n\nsource = $source\ntarget = $target\n" 10 80 || return 0
	cp -p $source $target
	dos2unix $target
	$msgbox "ScummVM Configuration Imported" 5 80
}

config_edit(){
	$infobox "Searching for ScummVM configuration files..." 3 80
	local title="Select source configuration file:"
	local list=$(find /media -iname 'scummvm*.ini' | sort -r | list_files)
	[ -n "$list" ] || return 106
	local choice="$(show_menu title list)"
	[ -n "$choice" ] || return 0
	local tempfile=$(mktemp -u)
	dos2unix $choice
	$editbox $choice 25 80 2> "$tempfile" \
		&& mv $tempfile $choice \
		|| rm $tempfile
}

config_delete(){
	local title="Delete a configuration file:"
	local list=$(find $APP -iname 'scummvm*.ini' | sort -r | list_files)
	[ -n "$list" ] || return 103
	local choice="$(show_menu title list)"
	[ -n "$choice" ] || return 0
	$yesno "Delete:\n\nconfig = $choice\n\n" 10 80 || return 0
	rm -v "$choice" 2>&1 | $programbox
}

mister_edit(){
	local tempfile=$(mktemp -u)
	dos2unix $CONF
	$editbox $CONF 25 80 2> "$tempfile" \
		&& mv $tempfile $CONF\
		|| rm $tempfile
}

license(){ $msgbox "$LICENSE" 25 80;}

quit(){ clear;exit 0;}

play(){ 
	local title="bbond007's ScummVM // ScummVM Launcher $version by Akuma (c) 2022 under GPLv3"
	local list=$(ls -r $APP | grep ^[0-9] | list_versions)
	[ -n "$list" ] || return 103
	local version="$(show_menu title list)"
	[ -n "$version" ] || return 0
	local exe="$APP/$version/scummvm$version"
	[ ${version:0:2} -lt 26 ] \
		&& local savepath="$APP/saves-old" \
		|| local savepath="$APP/saves"
	local options="\
		--opl-driver=db \
		--output-rate=48000 \
		--logfile="/tmp/scummvm$version.log" \
		--config="$exe.ini" \
		--savepath=$savepath \
		--themepath="$APP/$version" \
		--gui-theme="scummremastered${version%-*}" \
		--extrapath="$APP/extra"
		--fullscreen \
		--scaler=normal \
		--scale-factor=$(get_scale_factor) \
		--aspect-ratio"
	{
		local cpu_mask=03
		local midi=/media/fat/linux/MIDIMeister
		[ -f "$midi" ] && taskset $cpu_mask $midi quiet &
		taskset $cpu_mask $exe $options
		killall -q $midi
	} 2>&1 | $programbox
}

update_self(){
	online || return 100
	local self="$(readlink -f "$0")"
	local selfurl="https://raw.githubusercontent.com/Akuma-Git/misterfpga/main/scummvm.sh"
	local selfurl_version="$(urlcat "$selfurl"|sed -n 's,^version=,,;2p')"
	[ -n "$selfurl_version" ] || return 108

	[ "$selfurl_version" = "$version" ] && return 109 || {
		local tempfile="$(mktemp -u)"
		urlcat "$selfurl" > "$tempfile"
		mv "$tempfile" "$self"
		chmod +x "$self"
		exec "$self"
		exit 99
	}
	false
}

empty(){ :;}

### MAIN

TITLE="ScummVM Setup Utility $version by Akuma (c) 2022 under GPLv3"
MENU='
play			|Play
empty			|_
fullscreen_enable	|Enable Fullscreen (reboots)
fullscreen_disable	|Disable Fullscreen (reboots)
scummvm_install		|Install a ScummVM version
games_import		|Import Games
saves_import		|Import Saves
empty			|_
scummvm_delete		|Delete a ScummVM version
library_update		|Update Linux Packages
library_install		|Reinstall Linux Libraries
config_import		|Config: Import
config_edit		|Config: Edit ScummVM*.ini
config_delete		|Config: Delete
mister_edit		|MiSTer: Edit MiSTer.ini
update_self		|Update Self
empty			|_
quit			|Quit
'
#license			|GPLv3 Copyright License
### start
clear
play || continue
while :
do
	$(show_menu TITLE MENU) || eval $msgbox \"\$msg$?\" 5 80
	false
done

exit $?
