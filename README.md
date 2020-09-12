![CICD](https://github.com/masknetgoal634/nearcore-deploy/workflows/CICD/badge.svg)

# A Fully Automated NEARCore Docker Deployment using GitHub Actions and Watchtower

In this guide I will explain how to create a github actions workflow that automatically tests, builds, and deploys a Docker images that built from the latest source code (tags: "rc" and "beta") of [NEARCore](https://github.com/nearprotocol/nearcore) repository.

## Getting started

First of all, you need to familiarize yourself with [Github Actions](https://docs.github.com/en/actions) with which you can create any CI/CD workflows.
Also Githab Actions has a good [API](https://developer.github.com/v3/actions/)

To automate a set of tasks, you need to create workflows in your GitHub repository. GitHub looks for YAML files inside of the `.github/workflows` directory.
Events like commits, the opening or closing of pull requests, schedules, or web-hooks trigger the start of a workflow. For a complete list of available events, refer to this [documentation](https://docs.github.com/en/actions/reference/events-that-trigger-workflows).

In this guide we will use only a [schedule](https://docs.github.com/en/actions/reference/events-that-trigger-workflows#scheduled-events) event that allows to trigger a workflow at a scheduled time.

Workflows are composed of jobs, which run concurrently by default. You can configure jobs to depend on the success of other jobs in the same workflow.
Jobs contain a list of steps, which GitHub executes in sequence. A step can be a set of shell commands or an action, which is a pre-built, reusable step implemented either in TypeScript or inside a container. Some actions are provided by the GitHub team, while the open-source community maintains many more. [The GitHub Marketplace](https://github.com/marketplace?type=actions) keeps a catalog of known open-source actions.

GitHub Actions is free for all open-source projects, and private repositories get up to [2000 minutes per month](https://github.com/features/actions#pricing-details)(33,33 hours). For smaller projects, this means being able to take full advantage of automation from the very beginning at no extra cost. You can even use the system for free forever if you use self-hosted runners.

## CI/CD Workflow

>The workflow will create two docker images with tags: `dockerusername/nearcore:beta`(betanet) and `dockerusername/nearcore:rc`(testnet)

>If you don't have a Docker ID. Go to the Docker Hub and [create an account](https://docs.docker.com/docker-hub/). 

>Docker Hub is a hosted repository service provided by Docker for finding and sharing container images with your team.

Let get started to dive deep into our CI/CD workflow.

In the repository you will see our workflow [.github/workflows/main.yml](https://github.com/masknetgoal634/nearcore-deploy/blob/master/.github/workflows/main.yml)

Our workflow will trigger by schedule event (trigger every 10 minutes):
```
on:
  schedule:
    # Run the workflow every 10 minutes
    - cron: '*/10* * * *'
```
Global environment variables:
```
env:
  DOCKER_BUILDKIT: 1 
```
In our workflow we have one job:
```
jobs:
  build:
```
Also runs on Ubuntu latest 
```
runs-on: ubuntu-latest
```
Lets create a [strategy matrix](https://docs.github.com/en/actions/reference/workflow-syntax-for-github-actions#jobsjob_idstrategymatrix) to build and deploy different releases for `testnet` and `betanet`.

```
strategy:
  matrix:
    release-name: ["rc", "beta"]
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
