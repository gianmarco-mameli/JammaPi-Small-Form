#!/bin/bash
dialog --title "JammaPi aggiorna script" \
            --backtitle "JammaPi Menù" \
            --yesno "Vuoi aggiornare lo script della JammaPi? \n Al termine sarà riavviato il sistema!" 7 60
            response=$?
case $response in
               0)
                  cd /home/pi/JammaPi-Small-Form || exit $?
                  git reset --hard origin/master
                  git pull
                  bash /home/pi/JammaPi-Small-Form/install.sh
               ;;
               1)
                  bash /home/pi/JammaPi-Small-Form/script/menu.sh
               ;;
            esac
