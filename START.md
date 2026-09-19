To keep your laptop safe, we'll do all our work inside a Docker container. Please make sure you have Docker Desktop installed (https://www.docker.com/products/docker-desktop/).

If you were in AI++101, you can use that same docker image.

If not, here are the instructions for downloading and running that image.

Here is the setup guide for the class: https://github.com/jodyhagins/aipp101-starter/blob/main/docs/student-setup.md

You will basically need to install docker. The docker image you will need is already pre-built and can be downloaded. The dockerfile is part of the repo so you can build it yourself if you so choose. It includes dev tools and boost and some other things so it's pretty big.

You will need the docker image, whose full image is: ghcr.io/jodyhagins/aipp101-starter/workshop@sha256:d6a8c8324c2e3c6a39994ea42daf59a41af9bae16e480052ea112b626efdd028



You can then copy these commands directly:

export WORKSHOP_IMAGE='ghcr.io/jodyhagins/aipp101-starter/workshop@sha256:d6a8c8324c2e3c6a39994ea42daf59a41af9bae16e480052ea112b626efdd028'
docker pull "$WORKSHOP_IMAGE"


Post here if you have any issues.

I plan to arrive an hour before the workshop begins, in case you need help getting this working. I'll also have an assistant whose primary job will be helping people with Docker and/or project build issues.

The guide mentions an OpenRouter API key. That is for 101 only - we will not be using OpenRouter here.

