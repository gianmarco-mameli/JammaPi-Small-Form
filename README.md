## Aggiornamento installazione al 13/10/2026 ##

Clonare il progetto in `/home/pi/JammaPi-Small-Form` e lanciare il file
`install.sh` all'interno. I percorsi di RetroPie sotto `/opt/retropie` restano
invariati.

Se il progetto era installato sotto `/opt`, spostare il clone in
`/home/pi/JammaPi-Small-Form` e rieseguire l'installer dalla nuova posizione per
aggiornare i collegamenti e il servizio systemd.

### RetroPie su Raspbian Buster

Prima di eseguire `apt-get update`, l'installer rileva Raspbian Buster e corregge
le voci Buster dei vecchi mirror Raspbian in `/etc/apt/sources.list` e nei file
`/etc/apt/sources.list.d/*.list`, usando `https://legacy.raspbian.org/raspbian/`.
Ogni file modificato viene salvato una sola volta con suffisso `.jammapi.bak`.
Le altre distribuzioni, i repository di terze parti e il repository separato
`archive.raspberrypi.org/debian` non vengono modificati. Le verifiche delle
firme APT e dei certificati HTTPS restano abilitate.

Questo risolve il 404 del repository ritirato, ma Buster resta obsoleto:
per gli aggiornamenti di sicurezza serve una versione supportata del sistema.

### Configurazione e reinstallazione

L'installazione e la selezione HDMI/CRT ripuliscono le direttive JammaPi
preesistenti (anche duplicate o commentate) e riapplicano i valori previsti.
La configurazione viene scritta in una sezione globale `[all]`: le altre
impostazioni e sezioni restano invariate, ma eventuali personalizzazioni delle
direttive gestite da JammaPi vengono sostituite.

Il menu video offre HDMI con audio JAMMA (stereo), oppure CRT con audio JAMMA
(mono). HDMI disabilita le direttive DPI ma mantiene attivo l'audio analogico
tramite la successiva selezione JAMMA, con il corretto overlay audio per
Raspberry Pi 4 o per i modelli precedenti. L'audio HDMI resta selezionabile
separatamente dal menu audio.
Selezionare nuovamente la stessa uscita non accumula commenti o duplicati.
L'installazione parte dai valori CRT e propone poi la scelta dell'uscita video.
Anche `/etc/modules` e le opzioni CRT di RetroArch vengono normalizzati, mentre
il backup originale di `es_input.cfg`, se presente, non viene sovrascritto.

I file `vga666.dtbo` e `dt-blob.bin` vengono copiati nella partizione `/boot`,
non collegati simbolicamente: il filesystem FAT della partizione di avvio non
supporta i link simbolici. Le reinstallazioni sostituiscono le copie esistenti.

La selezione audio rileva le schede HDMI e Headphones da `/proc/asound/cards`
e aggiorna il dispositivo PCM e il controllo predefinito in `/etc/asound.conf`
usando gli identificativi ALSA, non numeri di scheda fissi. Sui vecchi kernel
con scheda unica bcm2835 ALSA usa il controllo `PCM Playback Route` per nome.
Le impostazioni mono/stereo vengono preservate. Se l'uscita non esiste, lo
script segnala un errore senza cambiare il dispositivo ALSA.

Il driver joystick usa `i2c_new_dummy_device()` sui kernel da 5.2 in poi
(incluso 5.10 di Buster), mantenendo la vecchia API sui kernel precedenti.
Per ricompilare dopo un aggiornamento del sorgente:

```sh
cd /home/pi/JammaPi-Small-Form/joypi
make clean
make
sudo make install
sudo modprobe joypi
```

Test delle modifiche ai file, senza privilegi root o hardware Raspberry Pi:

```sh
python3 -m unittest discover -s tests -v
```

# JammaPi !!!Aggiunto pieno supporto a Raspberry Pi 4!!!

![alt text](https://www.vincenzobini.it/media/JammaPi_small.jpg)

sito di riferimento: https://www.jammapi.it/

Script per installazione semplificata JammaPi Small Form Factor, da usare con cautela!

Eseguire l'installer dal clone completo (usa anche gli script di configurazione
contenuti nel repository):

```sh
cd /home/pi/JammaPi-Small-Form
bash install.sh
```


Versione solo Jamma e audio Mono/Stereo, disposta in maniera da poter raffreddare il raspberry senza problemi e tutta da saldare!

Per problemi aprite un ticket
