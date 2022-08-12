#!/bin/bash

#
# Attiva l'interfaccia video
#


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
            sudo sed -i's/dtoverlay=pwm-2chan,pin=18,func=2,pin2=19,func2=2/#dtoverlay=pwm-2chan,pin=18,func=2,pin2=19,func2=2/g' /boot/config.txt
			sudo sed -i's/dtoverlay=audremap,pins_18_19/#dtoverlay=audremap,pins_18_19/g' /boot/config.txt
			sudo sed -i's/disable_audio_dither=1/#disable_audio_dither=1/g' /boot/config.txt
			sudo sed -i's/audio_pwm_mode=2/#audio_pwm_mode=2/g' /boot/config.txt
			sudo sed -i's/dtoverlay=vga666-6/#dtoverlay=vga666-6/g' /boot/config.txt
			sudo sed -i's/enable_dpi_lcd=1/#enable_dpi_lcd=1/g' /boot/config.txt
			sudo sed -i's/display_default_lcd=1/#display_default_lcd=1/g' /boot/config.txt
			sudo sed -i's/dpi_output_format=6/#dpi_output_format=6/g' /boot/config.txt
			sudo sed -i's/dpi_group=2/#dpi_group=2/g' /boot/config.txt
			sudo sed -i's/dpi_mode/#dpi_mode/g' /boot/config.txt
			sudo sed -i's/hdmi_timings=/#hdmi_timings=/g' /boot/config.txt
			bash /opt/JammaPi-Small-Form/script/pixelperfect.sh -runc-off
			bash /opt/JammaPi-Small-Form/script/pixelperfect.sh -off
   			sudo sed -i's/#CRT/#HDMI/g' /boot/config.txt
			sleep 5
            ;;
		-SCART | -JAMMA)
			printf "\033[1;31m Attivo la SCART/JAMMA \033[0m\n"
            sudo sed -i's/#dtoverlay=pwm-2chan,pin=18,func=2,pin2=19,func2=2/dtoverlay=pwm-2chan,pin=18,func=2,pin2=19,func2=2/g' /boot/config.txt
			sudo sed -i's/#dtoverlay=audremap,pins_18_19/dtoverlay=audremap,pins_18_19/g' /boot/config.txt
			sudo sed -i's/#disable_audio_dither=1/disable_audio_dither=1/g' /boot/config.txt
			sudo sed -i's/#audio_pwm_mode=2/audio_pwm_mode=2/g' /boot/config.txt
			sudo sed -i's/#dtoverlay=vga666-6/dtoverlay=vga666-6/g' /boot/config.txt
			sudo sed -i's/#enable_dpi_lcd=1/enable_dpi_lcd=1/g' /boot/config.txt
			sudo sed -i's/#display_default_lcd=1/display_default_lcd=1/g' /boot/config.txt
			sudo sed -i's/#dpi_output_format=6/dpi_output_format=6/g' /boot/config.txt
			sudo sed -i's/#dpi_group=2/dpi_group=2/g' /boot/config.txt
			sudo sed -i's/#dpi_mode=87/dpi_mode=87/g' /boot/config.txt
			sudo sed -i's/#dpi_mode=9/dpi_mode=87/g' /boot/config.txt
			sudo sed -i's/dpi_mode=9/dpi_mode=87/g' /boot/config.txt
			sudo sed -i's/#hdmi_timings=/hdmi_timings=/g' /boot/config.txt
			bash /opt/JammaPi-Small-Form/script/pixelperfect.sh -runc-on
			bash /opt/JammaPi-Small-Form/script/pixelperfect.sh -on
    			sudo sed -i's/#HDMI/#CRT/g' /boot/config.txt
			printf "\033[0;32m !!!SPOSTARE I 2 DIP SWITCH SU ON!!! \033[0m\n"
			sleep 5
            ;;
	    	-HDMI-AUD)
			printf "\033[1;31m Attivo audio su HDMI \033[0m\n"
			amixer cset numid=3 "2"
			sleep 5
            ;;
	    	-JAMMA-AUD)
			printf "\033[1;31m Attivo audio su JAMMA/JACK \033[0m\n"
			amixer cset numid=3 "1"
			sleep 5
            ;;
	    	-AUD-MONO)
			printf "\033[1;31m Imposto l'audio MONO \033[0m\n"
			sudo sed -i's/0.0 1/0.0 1/g' /etc/asound.conf
			sudo sed -i's/0.1 0/0.1 0/g' /etc/asound.conf
			sudo sed -i's/1.0 0/1.0 1/g' /etc/asound.conf
			sudo sed -i's/1.1 1/1.1 0/g' /etc/asound.conf
			sleep 5
            ;;
	        -AUD-STEREO)
			printf "\033[1;31m Imposto l'audio STEREO \033[0m\n"
			sudo sed -i's/0.0 1/0.0 1/g' /etc/asound.conf
			sudo sed -i's/0.1 0/0.1 0/g' /etc/asound.conf
			sudo sed -i's/1.0 1/1.0 0/g' /etc/asound.conf
			sudo sed -i's/1.1 0/1.1 1/g' /etc/asound.conf
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
