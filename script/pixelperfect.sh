#!/bin/bash

#
# Attiva o disattiva il pixel-perfect
#

set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

set_runcommand()
{
    local name source target
    for name in runcommand-onend.sh runcommand-onstart.sh; do
        source="/opt/retropie/configs/all/$name$1"
        target="/opt/retropie/configs/all/$name$2"
        if [ -e "$source" ] || [ -L "$source" ]; then
            mv -f "$source" "$target"
        elif [ ! -e "$target" ] && [ ! -L "$target" ]; then
            echo "ERRORE: Script mancante: $source / $target" >&2
            return 1
        fi
    done
}

set_resolution()
{
    sudo bash "$SCRIPT_DIR/configure.sh" retroarch /opt/retropie/configs/all/retroarch.cfg "$1"
}


usage()
{
    echo "Pixel-Perfect"
    echo ""
	echo -e "\t-h --help"
    	echo -e "\t-on : attiva il pixel-perfect a 15khz"
	echo -e "\t-on31 : attiva il pixel-perfect a 31khz"
	echo -e "\t-off : disattiva il pixel-perfect"
	echo -e "\t-runc-on : attiva il runcommand"
	echo -e "\t-runc-off : disattiva il runcommand"
    echo ""
}

while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        -on)
			MODEL=$(tr -d '\0' < /proc/device-tree/model)
			if [[ "$MODEL" == *"Pi 4"* ]]; then
        		echo "ERRORE: Impossibile attivare il pixel perfect su pi4 al momento!"
				set_resolution 0
			else
				printf "\033[1;31m Attivo il Pixel-Perfect per la JammaPi \033[0m\n"
				set_resolution 1
				sleep 2
			fi
            ;;
	 -on31)
			printf "\033[1;31m Attivo il Pixel-Perfect per la JammaPi \033[0m\n"
			set_resolution 2
			sleep 2
            ;;
	-runc-on)
			printf "\033[1;31m Attivo il Runcommand \033[0m\n"
			set_runcommand .off ""
			sleep 2
            ;;
        -off)
			printf "\033[1;31m Disattivo il Pixel-Perfect per la JammaPi \033[0m\n"
			set_resolution 0
			sleep 2
            ;;
	-runc-off)
			printf "\033[1;31m Disattivo il runcommand \033[0m\n"
			set_runcommand "" .off
			sleep 2
            ;;
        *)
            echo "ERRORE: Parametro sconosciuto: \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done
