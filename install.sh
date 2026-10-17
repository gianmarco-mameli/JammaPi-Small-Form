#!/bin/bash
########################################################
## Vincenzo Bini 22/09/2019
## Versione 1.0
## Update 10/08/2022
## Versione 1.1
#########################################################

set -e

INSTALL_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONFIGURE="$INSTALL_DIR/script/configure.sh"
MODEL=$(tr -d '\0' < /proc/device-tree/model)

dialog --title "Script installazione JammaPi" --msgbox "Attenzione verranno ora installati i driver per il corretto funzionamento della Jammapi.
\n \nSe stai usando un immagine custom, non scaricata da retropie.org.uk, accertati di aver disattivato tutti gli script che usano i GPIO.
\n \nTerminata l'installazione ti verrà chiesto che uscita video abilitare! " 14 60

# cd /home/pi
sudo apt-get update
sudo apt-get install -y git libjpeg-dev dialog
# lsmod | grep 'joypi' > /dev/null 2>&1
#   if [ $? -eq 0 ] ; then
#   	echo "Kernel ok!"
#   else
#   	sudo apt-get install --reinstall -y raspberrypi-bootloader raspberrypi-kernel raspberrypi-kernel-headers
#   fi
# git clone https://github.com/gianmarco-mameli/JammaPi-Small-Form.git /home/pi/JammaPi-Small-Form
# cd /home/pi/JammaPi-Small-Form
# git reset --hard origin/master
# git pull
# chmod +x install.sh

##install jammapi overlay
	# cd /home/pi/JammaPi-Small-Form
	printf "\033[1;31m Modifico il config.txt per la JammaPi \033[0m\n"
	printf "\033[1;31m Installo overlay JammaPi \033[0m\n"
	sudo ln -sfn "$INSTALL_DIR/vga666.dtbo" /boot/overlays/vga666.dtbo
	sudo ln -sfn "$INSTALL_DIR/dt-blob.bin" /boot/dt-blob.bin
	sudo ln -sfn "$INSTALL_DIR/script/asound.conf" /etc/asound.conf
	sleep 2

  ##Modify Config.txt to Default
	sudo bash "$CONFIGURE" boot /boot/config.txt CRT "$MODEL"
	echo "Config.txt modificato!"
	sleep 2

##install jammapi joystick driver

	printf "\033[1;31m Installo driver Joystick \033[0m\n"
	sudo bash "$CONFIGURE" modules /etc/modules
        if lsmod | grep -q '^joypi '; then
        echo "Joystick già installato!"
        else
	cd "$INSTALL_DIR/joypi/"
	make clean
	make
	sudo make install
	sudo insmod joypi.ko
	echo "Modulo impostato!"
        fi
	ln -sf /home/pi/JammaPi-Small-Form/joypi/JoyPi\ Joystick\ 0.cfg /opt/retropie/configs/all/retroarch-joypads/JoyPi\ Joystick\ 0.cfg
	ln -sf /home/pi/JammaPi-Small-Form/joypi/JoyPi\ Joystick\ 1.cfg /opt/retropie/configs/all/retroarch-joypads/JoyPi\ Joystick\ 1.cfg
	if [ ! -e /opt/.emulationstation/es_input.cfg.bak ] && [ -f /opt/.emulationstation/es_input.cfg ] && [ ! -L /opt/.emulationstation/es_input.cfg ]; then
	    sudo cp -p /opt/.emulationstation/es_input.cfg /opt/.emulationstation/es_input.cfg.bak
	fi
	ln -sf /home/pi/JammaPi-Small-Form/joypi/es_input.cfg /opt/retropie/configs/all/emulationstation/es_input.cfg
	sleep 2

##install jammapi service and script script
	chmod u+x /home/pi/JammaPi-Small-Form/script/pixelperfect.sh
	chmod u+x /home/pi/JammaPi-Small-Form/script/interfaccia.sh
	chmod u+x /home/pi/JammaPi-Small-Form/script/jammapi.sh
	sudo ln -sf /home/pi/JammaPi-Small-Form/services/jammapi.service /etc/systemd/system/jammapi.service
	sudo systemctl daemon-reload
	sudo systemctl enable jammapi.service
	sudo systemctl start jammapi.service
	echo "Script impostato!"
	sleep 2



##install jammapi menu script
	printf "\033[1;31m Installo menu x RetroPie \033[0m\n"
	ln -sf /home/pi/JammaPi-Small-Form/script/menu.sh '/home/pi/RetroPie/retropiemenu/JammaPi.sh'
	sleep 2

#   ##Add Emulationstation basic themes...
# 	printf "\033[1;31m Installo temi Emulationstation \033[0m\n"
# 	cd /etc/emulationstation/themes/
# 	sudo git clone https://github.com/ehettervik/es-theme-pixel.git
# 	sleep 2

  ##install retropie resolution switch
		printf "\033[1;31m installo script risoluzioni 15khz... \033[0m\n"
		ln -sf /home/pi/JammaPi-Small-Form/script/runcommand-onend.sh /opt/retropie/configs/all/runcommand-onend.sh
		ln -sf /home/pi/JammaPi-Small-Form/script/runcommand-onstart.sh /opt/retropie/configs/all/runcommand-onstart.sh
		ln -sf /home/pi/JammaPi-Small-Form/script/vertical_list.txt /opt/retropie/configs/all/vertical_list.txt
		ln -sf /home/pi/JammaPi-Small-Form/script/exceptions_list.txt /opt/retropie/configs/all/exceptions_list.txt

		sudo bash "$CONFIGURE" retroarch /opt/retropie/configs/all/retroarch.cfg
		echo "Modulo impostato!"
		sleep 2


#   ##Disable swap
#   		printf "\033[1;31m disabilito la swap per rendere più stabile il \033[0m\n"
# 		printf "\033[1;31m sistema in caso di spegnimenti improvvisi \033[0m\n"
# 		sudo grep '/var/log' /etc/fstab > /dev/null 2>&1
# 		if [ $? -eq 0 ] ; then
# 			echo "Già modificato!"
# 		else
# 		sudo dphys-swapfile swapoff
# 		sudo dphys-swapfile uninstall
# 		sudo update-rc.d dphys-swapfile remove
# 		sudo sh -c "echo 'tmpfs /var/log tmpfs size=1M,noatime 0 0' >> /etc/fstab"
# 		echo "Modulo impostato!"
# 		fi


##Choice of video output
		bash /home/pi/JammaPi-Small-Form/script/switchvideo.sh 1

    	printf "\033[0;32m !!!INSTALLAZIONE COMPLETATA!!! \033[0m\n"
		printf "\033[0;32m     !!!RIAVVIO IN CORSO!!! \033[0m\n"
  		sleep 5

sudo reboot
