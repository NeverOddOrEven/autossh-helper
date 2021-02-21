FROM ubuntu:18.04

RUN apt-get update && apt-get install autossh -y && apt-get autoclean

WORKDIR /root

COPY ./create-autossh-tunnel.sh ./create-autossh-tunnel.sh

ENTRYPOINT [ "./create-autossh-tunnel.sh" ]

