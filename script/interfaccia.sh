#!/bin/bash

#
# Attiva l'interfaccia video
#

set -e
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

configure_video()
{
    local model
    model=$(tr -d '\0' < /proc/device-tree/model)
    sudo bash "$SCRIPT_DIR/configure.sh" "$1" /boot/config.txt "${2:-CRT}" "$model"
}


usage()
{
    echo "Modifica uscita audio/video"
    echo ""
	echo -e "\t-h --help"
	echo -e "\t-HDMI : attiva l'uscita HDMI"
	echo -e "\t-SCART -JAMMA : attiva l'uscita SCART/JAMMA"
	echo -e "\t-HDMI-AUD : attiva l'audio su HDMI"
	echo -e "\t-JAMMA-AUD : attiva l'audio su JAMMA/JACK"
	echo -e "\t-AUD-MONO : imposta l'audio MONO"
	echo -e "\t-AUD-STEREO : imposta l'audio STEREO"
    echo ""
}

while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        -HDMI)
			printf "\033[1;31m Attivo l'HDMI \033[0m\n"
			configure_video boot HDMI
			bash "$SCRIPT_DIR/pixelperfect.sh" -runc-off -off
			sleep 5
            ;;
		-SCART | -JAMMA)
			printf "\033[1;31m Attivo la SCART/JAMMA \033[0m\n"
			configure_video boot CRT
			bash "$SCRIPT_DIR/pixelperfect.sh" -runc-on -on
			printf "\033[0;32m !!!SPOSTARE I 2 DIP SWITCH SU ON!!! \033[0m\n"
			sleep 5
            ;;
	    	-HDMI-AUD)
			printf "\033[1;31m Attivo audio su HDMI \033[0m\n"
			sudo bash "$SCRIPT_DIR/select-audio.sh" HDMI
			sleep 5
            ;;
	    	-JAMMA-AUD)
			printf "\033[1;31m Attivo audio su JAMMA/JACK \033[0m\n"
			configure_video audio
			sudo bash "$SCRIPT_DIR/select-audio.sh" JAMMA
			sleep 5
            ;;
	    	-AUD-MONO)
			printf "\033[1;31m Imposto l'audio MONO \033[0m\n"
			sudo sed -i 's/0.0 1/0.0 1/g' /etc/asound.conf
			sudo sed -i 's/0.1 0/0.1 0/g' /etc/asound.conf
			sudo sed -i 's/1.0 0/1.0 1/g' /etc/asound.conf
			sudo sed -i 's/1.1 1/1.1 0/g' /etc/asound.conf
			sleep 5
            ;;
	        -AUD-STEREO)
			printf "\033[1;31m Imposto l'audio STEREO \033[0m\n"
			sudo sed -i 's/0.0 1/0.0 1/g' /etc/asound.conf
			sudo sed -i 's/0.1 0/0.1 0/g' /etc/asound.conf
			sudo sed -i 's/1.0 1/1.0 0/g' /etc/asound.conf
			sudo sed -i 's/1.1 0/1.1 1/g' /etc/asound.conf
			sleep 5
            ;;
		*)
            echo "ERRORE: Parametro sconosciuto: \"$PARAM\""
            usage
            exit 1
            ;;
    esac
    shift
done
