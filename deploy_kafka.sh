#!/bin/bash
# ======================================
# Apache Kafka Deployment Script on Kubernetes
# Distributed System Lab 1
# ======================================

set -e

# --- CONFIG SECTION ---
NAMESPACE="kafka"
STORAGE_CLASS_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"
KAFKA_CLUSTER_ID="my-cluster-id"     # bạn có thể đổi nếu muốn
REPLICAS=2                           # số lượng Kafka brokers
# ------------------------

echo "[1/6] Cài đặt Local Path Provisioner (StorageClass)"
kubectl apply -f $STORAGE_CLASS_URL

echo "[2/6] Tạo namespace Kafka"
kubectl create namespace $NAMESPACE || echo "(namespace $NAMESPACE đã tồn tại)"

echo "[3/6] Tạo file cấu hình kafka.yaml"
cat <<EOF | tee kafka.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: kafka-config
  namespace: $NAMESPACE
data:
  base.properties: |
    process.roles=broker,controller
    controller.listener.names=CONTROLLER
    listeners=PLAINTEXT://:9092,CONTROLLER://:9093
    inter.broker.listener.name=PLAINTEXT
    log.dirs=/var/lib/kafka/data
    controller.quorum.bootstrap.servers=kafka-0.kafka-service.$NAMESPACE.svc.cluster.local:9093,kafka-1.kafka-service.$NAMESPACE.svc.cluster.local:9093
    controller.quorum.voters=0@kafka-0.kafka-service.$NAMESPACE.svc.cluster.local:9093,1@kafka-1.kafka-service.$NAMESPACE.svc.cluster.local:9093

---
apiVersion: v1
kind: Service
metadata:
  name: kafka-service
  namespace: $NAMESPACE
spec:
  ports:
    - name: kafka
      port: 9092
      targetPort: 9092
    - name: controller
      port: 9093
      targetPort: 9093
  clusterIP: None
  selector:
    app: kafka

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  namespace: $NAMESPACE
spec:
  serviceName: kafka-service
  replicas: $REPLICAS
  selector:
    matchLabels:
      app: kafka
  template:
    metadata:
      labels:
        app: kafka
    spec:
      containers:
      - name: kafka
        image: apache/kafka:latest
        command: [ "sh", "-c" ]
        args:
        - |
          NODE_ID=\$(hostname | awk -F'-' '{print \$2}');
          CLUSTER_ID="$KAFKA_CLUSTER_ID";
          echo "node.id=\$NODE_ID" >> /opt/kafka/config/server.properties;
          echo "advertised.listeners=PLAINTEXT://kafka-\$NODE_ID.kafka-service.$NAMESPACE.svc.cluster.local:9092,CONTROLLER://kafka-\$NODE_ID.kafka-service.$NAMESPACE.svc.cluster.local:9093" >> /opt/kafka/config/server.properties;
          cat /kafka/config/base.properties >> /opt/kafka/config/server.properties;
          /opt/kafka/bin/kafka-storage.sh format -t \$CLUSTER_ID -c /opt/kafka/config/server.properties
          /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
        ports:
        - containerPort: 9092
        - containerPort: 9093
        volumeMounts:
        - name: datadir
          mountPath: /var/lib/kafka/data
        - name: config
          mountPath: /kafka/config
      volumes:
      - name: config
        configMap:
          name: kafka-config
  volumeClaimTemplates:
  - metadata:
      name: datadir
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-path
      resources:
        requests:
          storage: 10Gi
EOF

echo "[4/6] Triển khai Kafka StatefulSet"
kubectl apply -f kafka.yaml

echo "[5/6] Chờ Kafka pods khởi động..."
kubectl -n $NAMESPACE rollout status statefulset kafka --timeout=300s

echo "[6/6] Hoàn tất! Danh sách pods:"
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "✅ Kafka đã được triển khai thành công trong namespace '$NAMESPACE'."
echo "👉 Khi tất cả pods ở trạng thái Running, bạn có thể tạo topic bằng lệnh:"
echo "   kubectl exec -it kafka-0 -n $NAMESPACE -- /opt/kafka/bin/kafka-topics.sh --create --bootstrap-server localhost:9092 --topic test-topic"
echo ""
echo "👉 Kiểm tra topics:"
echo "   kubectl exec -it kafka-0 -n $NAMESPACE -- /opt/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092"
echo ""
echo "👉 Nếu muốn xóa Kafka:"
echo "   kubectl delete -f kafka.yaml"
echo "   kubectl delete pvc -l app=kafka -n $NAMESPACE"
