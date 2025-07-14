#!/bin/bash

echo "=== Monitoring Stack Diagnostics ==="
echo ""

echo "1. Pod Status Details:"
kubectl describe pod -n monitoring | grep -A 10 -B 5 "Events:\|Error\|Failed\|Warning"

echo ""
echo "2. Resource Usage:"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
kubectl top pods -n monitoring 2>/dev/null || echo "Metrics server not available"

echo ""
echo "3. Node Resources:"
kubectl describe nodes | grep -A 5 "Allocated resources"

echo ""
echo "4. Storage Check:"
kubectl get pvc -n monitoring
kubectl get pv

echo ""
echo "5. Image Pull Status:"
kubectl get pods -n monitoring -o wide
kubectl describe pod -n monitoring | grep -A 5 -B 5 "image"

echo ""
echo "6. Events:"
kubectl get events -n monitoring --sort-by='.lastTimestamp' | tail -20

echo ""
echo "7. Disk Space on Node:"
df -h

echo ""
echo "8. Memory Usage:"
free -h
