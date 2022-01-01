# setup_minikube_ubuntu
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

kubectl version --client

curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube
sudo mkdir -p /usr/local/bin/
sudo install minikube /usr/local/bin/

sudo apt install -y conntrack # Connection tracking (“conntrack”) is a core feature of the Linux kernel's networking stack

alias mk="minikube"
alias kb="kubectl"

minikube start --driver=docker
#minkube delete

minikube status
kubectl cluster-info

kubectl get po -A
