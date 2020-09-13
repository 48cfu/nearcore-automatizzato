![nearcore-updater](https://github.com/48cfu/nearcore-automatizzato/workflows/CICD/badge.svg)
# Preparazione
1. Forka e clona questa repo
1. Crea un [personal access token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token)
1. Aggiungi il token appena generato nel tuo `.bashrc`
```bash
nano ~/.bashrc
```
All fine del file aggiungere `export GIT_PERSONAL_TOKEN=xxxxxxxxxxxxxxxxxxxxxxx` poi `Ctrl+x` e Salva con `y`.
1. Inserisci il tuo nome utente git all'interno di `carabiniere.sh`
1. (Dopo aver completato TUTTI gli altri punti di questa guida torna su questo punto) Esegui i seguente comandi (oppure crea un servizio usando `systemtcl`)
```bash
sudo apt install tmux
tmux new -s nearcore-updater
./carabiniere.sh
```

Per uscire dal terminale utilizzare `Ctrl+b ` e poi `d`. Se vorrai tornare nel terminale con i log di `carabiniere` utilizza `tmux attach -t nearcore-updater`.

# Un framework di automazione di nearcore 
In questa guida spiegherò come creare un flusso di lavoro tramite [Github Actions](https://docs.github.com/en/actions) che compili, simuli e faccia il deployement automatico dell'immagine Docker costruito dall'ultimo codice sorgente (tag: "rc" e "beta") del repository [nearcore](https://github.com/nearprotocol/nearcore). 

## Introduzione
Prima di tutto, devi familiarizzare con GitHub Actions con cui puoi creare qualsiasi flusso di lavoro CI/CD tramite le [API](https://developer.github.com/v3/actions/).

Per automatizzare una serie di attività, devi creare flussi di lavoro nel tuo repository GitHub. GitHub cerca i file YAML all'interno della directory `.github/workflows`. Eventi come commit, apertura o chiusura di richieste pull, pianificazioni o web-hook innescano l'inizio di un flusso di lavoro. Per un elenco completo degli eventi disponibili, fare riferimento alla documetazione apposita [qui](https://docs.github.com/en/actions/reference/events-that-trigger-workflows).

In questa guida utilizzeremo solo uno [`scheduled events`](https://docs.github.com/en/actions/reference/events-that-trigger-workflows#scheduled-events) che consente di attivare un flusso di lavoro in un momento pianificato.

I flussi di lavoro sono composti da tasks che di default vengono eseguiti contemporaneamente. È possibile configurare i tasks in modo che dipendano dal successo di altri tasks nello stesso flusso di lavoro. I tasks contengono un elenco di passaggi, che GitHub esegue in sequenza. Un passaggio può essere un insieme di comandi della shell o un'azione, che è un pre-compilato, riutilizzabile e implementato in TypeScript o all'interno di un contenitore. Alcune azioni sono fornite dal team di GitHub, mentre la comunità open source ne mantiene molte di più. Il [GitHub Marketplace](https://github.com/marketplace?type=actions) mantiene un catalogo di azioni open-`source note.

GitHub Actions è gratuito per tutti i progetti open-source.

## Flusso di lavoro CI/CD

>Il flusso di lavoro creerà due immagini docker con tag: `dockerusername/nearcore:beta`(betanet) e `dockerusername/nearcore:rc`(testnet).

>Se non disponi di un ID Docker vai al Docker Hub e [crea un account](https://docs.docker.com/docker-hub/). 

Cominciamo ad approfondire il nostro flusso di lavoro CI/CD. Nella repository vedrai il nostro flusso di lavoro [`.github/workflows/main.yml`](https://github.com/48cfu/nearcore-automatizzato/blob/master/.github/workflows/main.yml).

Il nostro flusso di lavoro si attiverà ogni 45 minuti:

```yml
# Esegue il flusso di lavoro solo quando triggerato da uno script esterno
on: [repository_dispatch]
```
Variabili globali d'ambiente:
```yml
env:
  DOCKER_BUILDKIT: 1 
```
Lo scopo di questo flusso è la compilazione di nearcore:
```yml
jobs:
  build:
```
Specifichiamo la versione di Ubuntu
```yml
runs-on: ubuntu-latest
```
Creiamo una [strategy matrix](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions#jobsjob_idstrategymatrix) che aiutare con la compilazione e il deployement di differenti release per `testnet` e `betanet`.

```yml
strategy:
  matrix:
    release-name: ["betanet", "testnet", "mainnet"]
```

Come accennato in precedenza, il flusso di lavoro contiene una sequenza di tasks che GitHub eseguirà in sequenza.
1.  Ottieni il tag GitHub in modo da permettere allo script di scaricare e salvare l'apposita versione di nearcore ("rc" or "beta")
```bash
echo $(curl -s https://api.github.com/repos/nearprotocol/nearcore/releases | jq -c -r --arg regex "$regex" 'map(select(.tag_name | test($regex)))[0].tag_name') > tag-github.txt
```
2. Ottieni i tag Docker Hub dove lo script controlla gli ultimi tag delle immagini docker già presenti nella nostra repository [docker hub] (https://hub.docker.com). Se esiste un tag github del passaggio precedente nella repository docker il flusso di lavoro verrà annullato. In caso contrario il nuovo tag github verrà utilizzato per costruire e pubblicare una nuova immagine docker

>`DOCKER_IMAGE_NAME` - [a public docker hub repository](https://docs.docker.com/docker-hub/repos/). (Per esempio `dockerusername/nearcore`)  
>È necessario creare della variabili segrete `DOCKER_IMAGE_NAME`, `DOCKER_USERNAME` e `DOCKER_PASSWORD` tramite Github Secrets ([creazione e salvataggio di segreti crittati](https://docs.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets)).
```yml
# if previous step is success
if: ${{ success() }}
        env:
          DOCKER_IMAGE_NAME: ${{ secrets.DOCKER_IMAGE_NAME }}
        run: |
          ...
```
3. La pubblicazione immagine del tag Github nel Registry  utilizza un'[azione pre-compilazione] (https://github.com/elgohr/Publish-Docker-Github-Action) che si occupa di pubblicare containers docker. Compilerà e pubblicherà l'immagine docker con i tag piu recenti (eg. `nearcore:1.14.0-beta.3` or `nearcore:1.13.0-rc.3`).

![](./immagini/docker-tags.png?raw=true) 

>`DOCKER_USERNAME` - l'ID Docker.

>`DOCKER_PASSWORD` - la password Docker.


4. **Installazione Rust** - un'azione che installa Rust.

5. **Clonazione Nearcore** - un'azione che clona la repository [nearcore](https://github.com/nearprotocol/nearcore) con il tag specificato al punto 1. 

6. **Test Cargo** - Esegue i test per verificare il funzionamento corretto di `nearcore`.

7. **Test Neard** - Esecuzione dei test nella directory `nearcore/neard/tests`.

8. **Pubblicazione immagine piu recente di Docker nel Registry** - compilazione e pubblicazione delle immagini dockercon i tag specificati in `${{ matrix.release-name }}` (e.g. `nearcore:beta` oppure `nearcore:rc`).

![](./immagini/compilazione.png?raw=true) 


## Nearcore Docker

#### Installa Docker
```bash
sudo apt-get update
sudo apt install docker.io
```

Se usi [nearup](https://github.com/near/nearup) fermalo:

```bash
nearup stop
```
>Sarà sempre possibile riutilizzare `nearup`.

Dopo il primo avvio del flusso di lavoro nuove immagini docker (`dockerusername/nearcore:beta` e `dockerusername/nearcore:rc`) saranno disponibili e sara possibile eseguire `nearcore` con il seguente comando:
```bash
sudo docker run -dti \
     --restart always \
     --user 0 \
     --volume $HOME/.near/betanet/:/srv/near \
     --volume /tmp:/tmp \
     --name nearcore \
     --network=host \
     -p 3030 \
     -p 24567 dockerusername/nearcore:beta near --home /srv/near run
```

Per seguire i log:
```bash
sudo docker logs nearcore -f
```

## Watchtower

Per automatizzare gli aggiornamenti delle nostre immagini Docker possiamo utilizzare un ottimo strumento open-source [Watchtower](https://github.com/containrrr/watchtower).

Watchtower monitora i container in esecuzione e controlla le modifiche alle immagini da cui quei container sono stati originariamente avviati. Quando Watchtower rileva che un'immagine è cambiata, riavvia automaticamente il contenitore utilizzando la nuova immagine.

Con watchtower puoi aggiornare la versione in esecuzione della tua app containerizzata semplicemente eseguendo il push di una nuova immagine al Docker Hub o al tuo registro di immagini. Watchtower tirerà giù la tua nuova immagine, spegnerà con grazia il tuo contenitore esistente e lo riavvierà con le stesse opzioni che erano state utilizzate quando è stato distribuito inizialmente. È dunque possibile aggiornare nearcore utilizzando Watchtower.

Avvia il container di watchtower con il seguente comando:
```bash
sudo docker run -d \
    --name watchtower \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower
```
Watchtower inizierà a monitorare il contenitore `nearcore:beta` or `nearcore:rc`. Quando il flusso di lavoro invierà un'immagine a Docker Hub, Watchtower rileverà che è disponibile una nuova immagine (circa 5-6 minuti). Fermerà con grazia il contenitore e avvierà il contenitore usando la nuova immagine.

# Ringraziamenti
Per questa guida ringrazio [maskenetgoal634](https://github.com/masknetgoal634/nearcore-deploy).
