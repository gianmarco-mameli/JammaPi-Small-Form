#!/bin/bash

HEIGHT=10
WIDTH=60
BACKTITLE="JammaPi Menù"
TITLE="JammaPi switch audio"
MENU="Scegli una delle opzioni:"

OPTIONS=(1 "Switch audio su HDMI"
         2 "Switch audio su JAMMA/JACK"
         3 "Imposta audio Mono/Stereo"
         4 "Test audio")

CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

clear
case $CHOICE in
        1)
            dialog --title "Switch audio su HDMI" \
            --backtitle "JammaPi Menù" \
            --yesno "Vuoi attivare l'uscita audio su HDMI?" 6 60
            response=$?
case $response in
               0)
                  bash /home/pi/JammaPi-Small-Form/script/interfaccia.sh -HDMI-AUD
               ;;
               1)
                  bash /home/pi/JammaPi-Small-Form/script/audio.sh
               ;;
            esac
            ;;

        2)
            dialog --title "Switch audio su JAMMA/JACK" \
            --backtitle "JammaPi Menù" \
            --yesno "Vuoi attivare l'uscita audio su JAMMA/JACK?" 6 60
            response=$?
case $response in
               0)
                  bash /home/pi/JammaPi-Small-Form/script/interfaccia.sh -JAMMA-AUD
               ;;
               1)
		          bash /home/pi/JammaPi-Small-Form/script/audio.sh
               ;;
            esac
            ;;

        3)
            HEIGHT=10
            WIDTH=60
            BACKTITLE="JammaPi Menù"
            TITLE="JammaPi switch audio"
            MENU="Scegli una delle opzioni:"

            OPTIONS=(1 "Imposta audio MONO"
                     2 "Imposta audio STEREO")

            CHOICE=$(dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "$TITLE" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

            clear
            case $CHOICE in
            1)
			bash /home/pi/JammaPi-Small-Form/script/interfaccia.sh -AUD-MONO
			bash /home/pi/JammaPi-Small-Form/script/audio.sh
            ;;

            2)
			bash /home/pi/JammaPi-Small-Form/script/interfaccia.sh -AUD-STEREO
			bash /home/pi/JammaPi-Small-Form/script/audio.sh
            ;;

            esac
            ;;
        4)
            speaker-test -t wav -c 2 -p 1 -l 1
            ;;

esac

bash /home/pi/JammaPi-Small-Form/script/menu.sh
