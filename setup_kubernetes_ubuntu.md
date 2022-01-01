
# All steps to set up Kubernetes cluster with one master and one worker nodes.
# Task 01 - Install docker
https://docs.docker.com/engine/install/ubuntu/

ssh to the machine which will be set up as master node.

ssh -i C:DMZ1.pem ubuntu@XX.XXX.XXX.XX

sudo apt-get update
sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io -y
sudo usermod -aG docker $USER

# log out
exit

# log in
ssh -i C:DMZ1.pem ubuntu@XX.XXX.XXX.XX

docker info


# Task 02 - Install Kubernetes
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add
sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
sudo apt-get install kubeadm kubelet kubectl -y
sudo apt-mark hold kubeadm kubelet kubectl
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
sudo hostnamectl set-hostname k8s-master-01/k8s-node-01/k8s-node-02

sudo reboot

# https://kubernetes.io/docs/reference/ports-and-protocols/


# Task 03 - Change container runtime cgroup drive to systemd

# Check that below file either has systemd for container runtime cgroup driver, or nothing explicitly mentioned at all.
# Kubernetes recommends systemd
sudo cat /etc/systemd/system/kubelet.service.d/10-kubeadm.conf | grep systemd

# Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/ kubelet.conf --cgroup-driver=systemd"

# https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/

### Change docker to use systemd
docker info | grep 'group Driver'

#If group is not systemd, change it to systemd
sudo mkdir /etc/docker
#Add below lines to /etc/docker/daemon.json
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker

# Task 04 - Init Kubernetes - only to be run on master

sudo apt install net-tools

sudo kubeadm reset -f
#What is POD network Cidr in Kubernetes?
#Kubernetes assigns each node a range of IP addresses, a CIDR block, so that each Pod can have a unique IP address. The size of the CIDR block corresponds to the maximum number of Pods per node.

# Get private ip from master node
ifconfig eth0
curl http://169.254.169.254/latest/meta-data/local-ipv4

#All EC2 Instances get IP from the host CIDR.
#All Pods in Kubernetes will get IP from the Pod CIDR.
#All Kubernetes Services get clusterIPs from Service CIDR.

Init can be done with various options

#sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --ignore-preflight-errors=NumCPU --v=9

#sudo kubeadm init --service-cidr 10.96.0.0/12
#sudo kubeadm init --apiserver-advertise-address=192.168.0.111 --pod-network-cidr=10.244.0.0/16 --service-cidr 10.240.0.0/12 --kubernetes-version v1.22.2 --ignore-preflight-errors=NumCPU --v=5

Here, we are using this one. Replace apiserver with private ip of the master server
sudo kubeadm init --apiserver-advertise-address=172.31.45.213 --pod-network-cidr=10.244.0.0/16 --service-cidr 10.96.0.0/12 --ignore-preflight-errors=NumCPU,Mem --v=5

You will see output like below:

##########################################
[addons] Applied essential addon: CoreDNS
[addons] Applied essential addon: kube-proxy

Your Kubernetes control-plane has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

Alternatively, if you are the root user, you can run:

  export KUBECONFIG=/etc/kubernetes/admin.conf

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 172.31.45.213:6443 --token en5mr7.33h89rt55lrwrsik \
        --discovery-token-ca-cert-hash sha256:872b7fe83a97de024031ffdb4a0ca0e0174f4c68470d17f57806cea019c15030
##########################################

In case, you need to clean up the cluster setup:
#sudo kubeadm reset -f


Run the below commands shown in above output.
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

View the cluster config
kubectl get cm kubeadm-config -n kube-system -o yaml

View the current status of pods
kubectl get svc -o wide -A
kubectl get deploy -o wide -A
kubectl get pods -A
kubectl get pods -o wide --all-namespaces
kubectl get daemonset -o wide -A

Full list -> kubectl api-resources

pod (po)
replicationcontroller (rc)
deployment (deploy)
daemonset (ds)
statefulset (sts)
cronjob (cj)
replicaset (rs)
PersistentVolumes (pv)
PersistentVolumeClaims (pvc)
configmap (cm)
node (no)
secret
events (ev)
statefulset (sts)


View network plugin and pof infra container image
sudo cat /var/lib/kubelet/kubeadm-flags.env

# Task 05 - Apply pod network


Apply your Pod networking (Weave net)
sudo mkdir -p /var/lib/weave
head -c 16 /dev/urandom | base64 | sudo tee /var/lib/weave/weave-passwd
kubectl create secret -n kube-system generic weave-passwd --from-file=/var/lib/weave/weave-passwd
kubectl get secret -n kube-system

Apply your Pod networking
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&password-secret=weave-passwd&env.IPALLOC_RANGE=10.244.0.0/16"

kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')&password-secret=weave-passwd"


# verify the value of --pod-network-cidr
kubectl get nodes -o jsonpath='{.items[*].spec.podCIDR}'
kubectl cluster-info dump | grep -m 1 cluster-cidr
sudo grep cidr /etc/kubernetes/manifests/kube-*
ps -ef | grep "cluster-cidr"
kubectl get cm -o yaml -n kube-system kubeadm-config
kubectl get cm -n kube-system kubeadm-config -o=jsonpath="{.data.ClusterConfiguration}"

# check value for --service-cidr
kubectl cluster-info dump | grep -m 1 service-cluster-ip-range
kubeadm config print init-defaults
ps -aux | grep kube-apiserver | grep service-cluster-ip-range
SVCRANGE=$(echo '{"apiVersion":"v1","kind":"Service","metadata":{"name":"tst"},"spec":{"clusterIP":"1.1.1.1","ports":[{"port":443}]}}' | kubectl apply -f - 2>&1 | sed 's/.*valid IPs is //')
echo $SVCRANGE

# check value of pod network range
kubectl get pod -n kube-system | grep weave
kubectl -n kube-system logs weave-net-z4bwr -c weave | grep ipalloc-range

kubeadm config images list


# steps to remove weave-net if needed
#if need to delete
#kubectl delete -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
#kubectl delete -n kube-system daemonset weave-net
#kubectl delete -n kube-system rolebinding weave-net
#kubectl delete -n kube-system role weave-net
#kubectl delete -n kube-system clusterrolebinding weave-net
#kubectl delete -n kube-system clusterrole weave-net
#kubectl delete -n kube-system serviceaccount weave-net

#restart coredns, if needed
#kubectl rollout restart deployment -n kube-system coredns
#kubectl rollout status deployment -n kube-system coredns

# restart apiserver, if needed
kubectl -n kube-system delete pod -l 'component=kube-apiserver'

kubectl get pod -o wide --all-namespaces -n kube-system
kubectl get pod -o wide --all-namespaces
kubectl version
kubectl api-resources
kubectl api-versions
kubectl get pods -n kube-system
kubectl describe po coredns-64897985d-7q5zf -n kube-system

kubectl get pods --all-namespaces -o custom-columns=:metadata.namespace --field-selector spec.nodeName=$NODENAME

Here, you can verify that, by default, master nodes have taint so as not to run any application deployments or pod.
kubectl describe node k8s-master-01 | grep -i taint

# If you have deleted deploy coredns by mistake, then do this:
cd ~
git clone https://github.com/coredns/deployment.git
https://github.com/coredns/deployment/blob/master/kubernetes/deploy.sh
cd ~/deployment/kubernetes
./deploy.sh | kubectl apply -f -
kubectl scale deploy coredns --replicas=3 -n kube-system
----

#Another kind of Pod Network Deployment to Cluster, if needed. At one time, only one network can be deployed
#sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

# Task 06 - Add worker nodes to the cluster

Open ports on master and worker according to below link:
1. https://kubernetes.io/docs/reference/ports-and-protocols/
2. Allow the CNI 6783 and 6784 ports in the nodes security group

Control plane
Protocol	Direction	Port Range	Purpose	Used By
TCP	Inbound	6443	Kubernetes API server	All
TCP	Inbound	2379-2380	etcd server client API	kube-apiserver, etcd
TCP	Inbound	10250	Kubelet API	Self, Control plane
TCP	Inbound	10259	kube-scheduler	Self
TCP	Inbound	10257	kube-controller-manager	Self
Worker node(s)
Protocol	Direction	Port Range	Purpose	Used By
TCP	Inbound	10250	Kubelet API	Self, Control plane
TCP	Inbound	30000-32767	NodePort Services†	All


If needed to get the join token again, run this on control node:
kubeadm token list
kubeadm token create
If you do not have the value of --discovery-token-ca-cert-hash, you can get it by running the following command chain on the control-plane node:

openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
   openssl dgst -sha256 -hex | sed 's/^.* //'

Join Worker Node to Cluster
# Go to worker node
sudo kubeadm join 172.31.45.213:6443 --token en5mr7.33h89rt55lrwrsik \
        --discovery-token-ca-cert-hash sha256:872b7fe83a97de024031ffdb4a0ca0e0174f4c68470d17f57806cea019c15030

You will see messages like this:
##############################
[kubelet-start] Starting the kubelet
[kubelet-start] Waiting for the kubelet to perform the TLS Bootstrap...

This node has joined the cluster:
* Certificate signing request was sent to apiserver and a response was received.
* The Kubelet was informed of the new secure connection details.

Run 'kubectl get nodes' on the control-plane to see this node join the cluster.
#############################

kubectl get nodes -A -o wide

Steps to remove nodes, if needed:
	#Run on master
	kubectl get nodes
	kubectl drain k8s-node-01
	kubectl delete node k8s-node-01

	#Run on worker
	sudo rm /opt/cni/bin/weave-*
	sudo kubeadm reset -f
	If you want to download and run it yourself, it is:
	sudo curl -L git.io/weave -o /usr/local/bin/weave
	sudo chmod a+x /usr/local/bin/weave
	then
	weave reset
	$ kubectl apply -f https://git.io/weave-kube-2.8.1 -n kube-system
	you would remove them using:
	$ kubectl delete -f https://git.io/weave-kube-1.6 -n kube-system

Location of logs:
https://kubernetes.io/docs/tasks/debug-application-cluster/debug-cluster/
kubectl get nodes
kubectl cluster-info dump
Master
/var/log/kube-apiserver.log - API Server, responsible for serving the API
/var/log/kube-scheduler.log - Scheduler, responsible for making scheduling decisions
/var/log/kube-controller-manager.log - Controller that manages replication controllers
Worker Nodes
/var/log/kubelet.log - Kubelet, responsible for running containers on the node
/var/log/kube-proxy.log - Kube Proxy, responsible for service load balancing

Debugging:
https://kubernetes.io/docs/tasks/debug-application-cluster/


############################################
