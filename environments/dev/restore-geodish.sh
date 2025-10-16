#!/bin/bash
set -e

echo "🚀 Starting GeoDish restoration..."

# 1. Apply Terraform
echo "📦 Step 1: Applying Terraform infrastructure..."
terraform apply -auto-approve

# 2. Configure kubectl
echo "⚙️  Step 2: Configuring kubectl..."
aws eks update-kubeconfig --region ap-south-1 --name geodish-dev-eks

# 3. Wait for cluster
echo "⏳ Step 3: Waiting for cluster to be ready..."
sleep 60

# 4. Wait for ArgoCD
echo "🐙 Step 4: Waiting for ArgoCD..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s || true

# 5. Apply root app
echo "📱 Step 5: Applying root application..."
kubectl apply -f ~/geodish-gitops/argocd/applications/root-app.yaml

# 6. Wait for MongoDB to create PVC
echo "⏳ Step 6: Waiting for MongoDB to start..."
sleep 60

# 7. Delete new PVC
echo "🗑️  Step 7: Removing new PVC..."
kubectl delete pvc data-volume-geodish-mongodb-0 -n devops-app --ignore-not-found=true

sleep 10

# 8. Create PV with old volume
echo "💾 Step 8: Restoring MongoDB volume with your recipes..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mongodb-recipes-restored
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ebs-mongodb
  csi:
    driver: ebs.csi.aws.com
    volumeHandle: vol-0cd81865dea580065
    fsType: ext4
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data-volume-geodish-mongodb-0
  namespace: devops-app
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ebs-mongodb
  volumeName: mongodb-recipes-restored
  resources:
    requests:
      storage: 20Gi
EOF

# 9. Restart MongoDB
echo "🔄 Step 9: Restarting MongoDB..."
kubectl delete pod -n devops-app -l app.kubernetes.io/name=geodish-mongodb

# 10. Wait for MongoDB to be ready
echo "⏳ Step 10: Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=geodish-mongodb -n devops-app --timeout=300s

echo ""
echo "✅ ✅ ✅ RESTORATION COMPLETE! ✅ ✅ ✅"
echo ""
echo "🎉 Your recipes should be back!"
echo ""
echo "To access your app:"
echo "  kubectl port-forward -n devops-app svc/geodish-app-geodish-app 5000:5000"
echo ""
echo "Then open: http://localhost:5000"
echo ""