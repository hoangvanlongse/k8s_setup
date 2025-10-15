# Use CLI linux

# Worker node

## 1. Run .sh file
```sh
vi setup_master.sh
chmod +x setup_master.sh
sudo ./setup_master.sh
```

## 2. Get token
```sh
kubeadm token create --print-join-command
```

## 3. Get worker nodes
```sh
kubectl get nodes
```
# Master node

## 1. Run .sh file
```sh
vi setup_worker.sh
chmod +x setup_worker.sh
sudo ./setup_worker.sh
```
## 2. Join cluster
```sh
sudo kubeadm join 192.168.1.10:6443 --token abcdef.1234567890abcdef --discovery-token-ca-cert-hash sha256:xxxxxxxx

```