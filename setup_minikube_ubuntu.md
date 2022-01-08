# Set up minikube on Ubuntu
### Install docker
```console
ssh -i C:DMZ1.pem ubuntu@XX.XXX.XXX.XX
```

```console
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
```

Exit from the machine.
```console
exit
```

Do ssh again to the machine.
ssh -i C:DMZ1.pem ubuntu@XX.XXX.XXX.XX

Verify docker status
```console
docker info
```

### Install minikube
```console
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl

kubectl version --client

curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x minikube
sudo mkdir -p /usr/local/bin/
sudo install minikube /usr/local/bin/
sudo apt install -y conntrack # Connection tracking (“conntrack”) is a core feature of the Linux kernel's networking stack
```

### Start minikube
```console
alias mk="minikube"
alias kb="kubectl"

minikube start --driver=docker
#minikube delete

minikube status
kubectl cluster-info

kubectl get po -A
```
