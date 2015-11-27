#!/bin/bash

#build in two servers first
#for b in {1..2}
#do
#docker build -t myapp:latest .
#done

#lets delete running containers first
filename="running-containers"
while read -r line
do
    name=$line
    #echo "Name read from file - $name"
    docker rm -f $name
done < "$filename"


#build the images in different nodes
eval $(docker-machine env swarm-node00-devOps)
docker build -t myapp:latest .

eval $(docker-machine env swarm-node01-devOps)
docker build -t myapp:latest .

#clean up running containers
rm -f running-containers

#switch back to docker swarm to run containers on swarm
eval $(docker-machine env --swarm swarm-master-devOps)

for i in {1..5}
do
   message=$(docker run -d -P myapp)
   echo  $message >> running-containers
   echo "Creating container $message"

done
