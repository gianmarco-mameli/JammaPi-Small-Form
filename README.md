## Aggiornamento installazione al 13/10/2026 ##

Clonare il progetto in `/home/pi/JammaPi-Small-Form` e lanciare il file
`install.sh` all'interno. I percorsi di RetroPie sotto `/opt/retropie` restano
invariati.

Se il progetto era installato sotto `/opt`, spostare il clone in
`/home/pi/JammaPi-Small-Form` e rieseguire l'installer dalla nuova posizione per
aggiornare i collegamenti e il servizio systemd.

### Configurazione e reinstallazione

L'installazione e la selezione HDMI/CRT ripuliscono le direttive JammaPi
preesistenti (anche duplicate o commentate) e riapplicano i valori previsti.
La configurazione viene scritta in una sezione globale `[all]`: le altre
impostazioni e sezioni restano invariate, ma eventuali personalizzazioni delle
direttive gestite da JammaPi vengono sostituite.

La selezione HDMI disabilita le direttive DPI e audio analogico; CRT le riattiva
con il corretto overlay audio per Raspberry Pi 4 o per i modelli precedenti.
Selezionare nuovamente la stessa uscita non accumula commenti o duplicati.
L'installazione parte dai valori CRT e propone poi la scelta dell'uscita video.
Anche `/etc/modules` e le opzioni CRT di RetroArch vengono normalizzati, mentre
il backup originale di `es_input.cfg`, se presente, non viene sovrascritto.

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
