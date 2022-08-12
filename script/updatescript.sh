#!/bin/bash
dialog --title "JammaPi aggiorna script" \
            --backtitle "JammaPi Menù" \
            --yesno "Vuoi aggiornare lo script della JammaPi? \n Al termine sarà riavviato il sistema!" 7 60
            response=$?
case $response in
               0)
                  cd /opt/JammaPi-Small-Form
                  git reset --hard origin/master
                  git pull
                  wget -O - https://github.com/gianmarco-mameli/JammaPi-Small-Form/raw/master/install.sh | bash
               ;;
               1)
                  bash /opt/JammaPi-Small-Form/script/menu.sh
               ;;
            esac

