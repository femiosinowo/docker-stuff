log() {
	echo "=== $1"
}

# you probably don't want to change these
REGISTRATOR_TAG=v4
SWARM_MASTER=swarm-master
CONSUL_MASTER=$SWARM_MASTER
LOAD_BALANCER=load-balancer


# create swarm token
log "Creating Swarm token"
docker-machine create -d virtualbox local
eval "$(docker-machine env local)"
SWARM_TOKEN=$(docker run swarm create)

log "Swarm token is: $SWARM_TOKEN"

# create Swarm Master
log "Creating Swarm master"
docker-machine create \
    -d virtualbox \
    --swarm \
    --swarm-master \
    --swarm-discovery token://$SWARM_TOKEN \
    $SWARM_MASTER

log "Starting Consul in Swarm Master"

# bootstramp Consul master, that all othe consuls running in the nodes will join
#log "Creating Consul Master node"
#docker-machine create \
#	    -d virtualbox \
#	    $CONSUL_MASTER

eval "$(docker-machine env $CONSUL_MASTER)"
CONSUL_MASTER_IP=$(docker-machine ip $CONSUL_MASTER)
docker run -d --name $CONSUL_MASTER -h $CONSUL_MASTER \
		-p $CONSUL_MASTER_IP:8300:8300 \
		-p $CONSUL_MASTER_IP:8301:8301 \
		-p $CONSUL_MASTER_IP:8301:8301/udp \
		-p $CONSUL_MASTER_IP:8302:8302 \
		-p $CONSUL_MASTER_IP:8302:8302/udp \
		-p $CONSUL_MASTER_IP:8400:8400 \
		-p $CONSUL_MASTER_IP:8500:8500 \
		-p $CONSUL_MASTER_IP:53:53 \
		-p $CONSUL_MASTER_IP:53:53/udp \
		progrium/consul \
		-server \
		-advertise $(docker-machine ip $CONSUL_MASTER) \
		-bootstrap
log "Consul Master IP address: $CONSUL_MASTER_IP"

log "Starting registrator in Swarm master node"
eval $(docker-machine env $SWARM_MASTER)
docker run -d \
	-v /var/run/docker.sock:/tmp/docker.sock \
	-h registrator-swarm-master \
	--name registrator-swarm-master \
	gliderlabs/registrator:$REGISTRATOR_TAG \
	consul://$(docker-machine ip $SWARM_MASTER):8500 \
	-ip $(docker-machine ip $SWARM_MASTER)

# create Swarm nodes
SWARM_NODES=("node-01" "node-02" "node-03")
for i in "${SWARM_NODES[@]}"; do
	log "Creating Swarm node $i"
	docker-machine create \
	    -d virtualbox \
	    --swarm \
	    --swarm-discovery token://$SWARM_TOKEN \
	    $i

	NODE_IP=$(docker-machine ip $i)

	eval "$(docker-machine env $i)"
	docker run --name consul-$i -d -h $i \
		-p $NODE_IP:8300:8300 \
		-p $NODE_IP:8301:8301 \
		-p $NODE_IP:8301:8301/udp \
		-p $NODE_IP:8302:8302 \
		-p $NODE_IP:8302:8302/udp \
		-p $NODE_IP:8400:8400 \
		-p $NODE_IP:8500:8500 \
		-p $NODE_IP:53:53 \
		-p $NODE_IP:53:53/udp \
		progrium/consul \
		-server \
		-advertise $NODE_IP \
		-join $CONSUL_MASTER_IP

	log "Starting Registrator in node $i"
	eval $(docker-machine env $i)
	docker run -d \
		-v /var/run/docker.sock:/tmp/docker.sock \
		-h registrator-$i \
		--name registrator-$i \
		gliderlabs/registrator:$REGISTRATOR_TAG \
		consul://$NODE_IP:8500 \
		-ip $NODE_IP

	# Run the local haproxy
	docker run \
		-d \
		-e SERVICE_NAME=rest \
		--name=load-balancer \
		--dns $NODE_IP \
		-p 80:80 \
		-p 1936:1936 \
		sirile/haproxy
done

# start the example service, in *any* of the nodes; unfortunately, docker-machine does not support
# setting Swarm labels yet so this container could end up in the consul-master node 
eval "$(docker-machine env --swarm $SWARM_MASTER)"
#SERVICE=("service-01" "service-02")
SERVICES=("service-01" "service-02" "service-03")
for i in "${SERVICES[@]}"; do
	docker run \
		-d \
		-e SERVICE_NAME=hello/v1 \
		-e SERVICE_TAGS=rest \
		-h hello-$i \
		--name hello-$i \
		-p :80 \
		sirile/scala-boot-test
done

# Finally, create the reverse proxy and load balancer
log "Creating load balancer"
docker-machine create \
	-d virtualbox \
	$LOAD_BALANCER

# start the load balancer
eval "$(docker-machine env $LOAD_BALANCER)"
docker run \
	-d \
	-e SERVICE_NAME=rest \
	--name=$LOAD_BALANCER \
	--dns $CONSUL_MASTER_IP \
	-p 80:80 \
	-p 1936:1936 \
	sirile/haproxy

docker run -d --name $LOAD_BALANCER -h $LOAD_BALANCER \
	-p $CONSUL_MASTER_IP:8300:8300 \
	-p $CONSUL_MASTER_IP:8301:8301 \
	-p $CONSUL_MASTER_IP:8301:8301/udp \
	-p $CONSUL_MASTER_IP:8302:8302 \
	-p $CONSUL_MASTER_IP:8302:8302/udp \
	-p $CONSUL_MASTER_IP:8400:8400 \
	-p $CONSUL_MASTER_IP:8500:8500 \
	-p $CONSUL_MASTER_IP:53:53 \
	-p $CONSUL_MASTER_IP:53:53/udp \
	progrium/consul \
	-server \
	-advertise $(docker-machine ip $CONSUL_MASTER) \
	-bootstrap

docker run -d \
	-v /var/run/docker.sock:/tmp/docker.sock \
	-h load-balancer \
	--name registrator-load-balancer \
	gliderlabs/registrator:$REGISTRATOR_TAG \
	consul://$NODE_IP:8500 \
	-ip $NODE_IP	

LB_IP=$(docker-machine ip $LOAD_BALANCER)
log "Access the load balancer at http://$LB_IP/hello/v1. Haproxy admin interface at http://$LB_IP:1936."
