![CICD](https://github.com/48cfu/nearcore-automatizzato/workflows/CICD/badge.svg)
# Un framework di automazione di nearcore tramite GitHub Actions e Watchtower

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

```bash
on:
  schedule:
    # Esegui il flusso di lavoro ogni 45 minuti
    - cron: '*/45* * * *'
```
Variabili globali d'ambiente:
```
env:
  DOCKER_BUILDKIT: 1 
```
Lo scopo di questo flusso è la compilazione di nearcore:
```
jobs:
  build:
```
Specifichiamo la versione di Ubuntu
```
runs-on: ubuntu-latest
```
Creiamo una [strategy matrix](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions#jobsjob_idstrategymatrix) che aiutare con la compilazione e il deployement di differenti release per `testnet` e `betanet`.

```
strategy:
  matrix:
    release-name: ["betanet", "testnet", "mainnet"]
```

As mentioned abowe jobs contain a list of steps, which GitHub executes in sequence.

Step 1: **Get Github Tag** where the script downloading and saving a github tag for a given release name ("rc" or "beta")
```
echo $(curl -s https://api.github.com/repos/nearprotocol/nearcore/releases | jq -c -r --arg RELEASE_NAME "$RELEASE_NAME" 'map(select(.tag_name | contains($RELEASE_NAME)))[0].tag_name') > github-tag.txt
```
Step 2: **Get Docker Hub Tags** where the script checks the latest tags of docker images that we have already at our [docker hub](https://hub.docker.com) repository if a github tag from the previuos step exists in the docker repo then the workflow will be cancelled if not then we have a new github tag and it's the case to build and publish a new docker image

> `DOCKER_IMAGE_NAME` - [a public docker hub repository](https://docs.docker.com/docker-hub/repos/). (ex. `dockerusername/nearcore`)  
>You have to create a secret github variable `DOCKER_IMAGE_NAME`. -> [Creating and storing encrypted secrets](https://docs.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets)
```
# if previous step is success
if: ${{ success() }}
        env:
          DOCKER_IMAGE_NAME: ${{ secrets.DOCKER_IMAGE_NAME }}
        run: |
          ...
```
Step 3: **Publish GitHub Image Tag to Registry** where [elgohr/Publish-Docker-Github-Action@master](https://github.com/elgohr/Publish-Docker-Github-Action) is a pre-built action that publishes docker containers. It will build and publish a docker images with the latest github tags (ex. `nearcore:1.8.0-beta.2` or `nearcore:1.7.0-rc.5`).
The logic of this step is to save the latest github tag to a docker hub repo as a docker image and then check the tags every time to build and publish only new releases of nearcore.

>`DOCKER_USERNAME` - a Docker ID.

>`DOCKER_PASSWORD` - a Docker ID password.

>You have to create a secret github variables `DOCKER_USERNAME` and `DOCKER_PASSWORD`. -> [Creating and storing encrypted secrets](https://docs.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets)

Step 4: **Install Rust** - an action which install Rust.

Step 5: **Clone NEARCore** - an action which clone [nearcore](https://github.com/nearprotocol/nearcore) with a tag from step 1.

Step 6: **Cargo Test** - execute tests of a nearcore packages.

Step 7: **Test Neard** - execute tests of neard located in `nearcore/neard/tests`

Step 8: **Publish Latest Docker Image to Registry** - will build and publish(concurrently) a docker images with `${{ matrix.release-name }}`(ex. `nearcore:beta` or `nearcore:rc`) tags.


## NEARCore Docker

#### Install Docker (if not installed)
```
sudo apt-get update
sudo apt install docker.io
```

If you are using [nearup](https://github.com/near/nearup) just stop the node:

```
nearup stop
```
>In the future if you will not use docker, you can use nearup again without any problems. 

After the first run of our workflow a new docker images(`dockerusername/nearcore:beta` and `dockerusername/nearcore:rc`) should be available and we can run the near node with the following command:
```
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

To watch the logs:
```
sudo docker logs nearcore -f
```

## Watchtower

To automate updates of our docker images we can use a great open source tool [Watchtower](https://github.com/containrrr/watchtower).

Watchtower monitors running containers and watches for changes to the images those containers were originally started from. When Watchtower detects that an image has changed, it automatically restarts the container using the new image.  

>With watchtower you can update the running version of your containerized app simply by pushing a new image to the Docker Hub or your own image registry. Watchtower will pull down your new image, gracefully shut down your existing container and restart it with the same options that were used when it was deployed initially. 

> With watchtower you can update nearcore, node exporter, near exporter,.... 

Run the watchtower container on your node with the following command:
```
sudo docker run -d \
    --name watchtower \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower
```
Now, Watchtower will start monitoring `nearcore:beta` container. When the workflow push an image to Docker Hub, Watchtower, will detect that a new image is available(about 5-6 minutes). It will gracefully stop the container and start the container using the new image.

## Conclusion

A big plus from using workflows is not only free automation, but also saving the entire history of deployments.

Hopefully this guide along with the workflow will make it easier for you to use Github Actions to build and deploy a new releases of [NEARCore](https://github.com/nearprotocol/nearcore).

>To use this workflow just fork the repository (or create your own public/private) and [set up secret variables](https://docs.github.com/en/actions/configuring-and-managing-workflows/creating-and-storing-encrypted-secrets): `DOCKER_IMAGE_NAME`, `DOCKER_USERNAME` and `DOCKER_PASSWORD`
