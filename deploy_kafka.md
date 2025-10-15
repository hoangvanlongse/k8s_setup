## 1. Run .sh file
```sh
vi deploy_kafka.sh
chmod +x deploy_kafka.sh
./deploy_kafka.sh
```
## 2. Get pod & service 
```sh
kubectl get pods -n kafka
kubectl get svc -n kafka
```
## 2. Delete pod
```sh
kubectl delete -f kafka.yaml
kubectl delete pvc -l app=kafka -n kafka
```