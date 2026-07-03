#!/bin/bash
# Script de inicio automatico para ELCHINO Restobar
# Uso: ./startup-elchino.sh <EC2-ROLE>
# Roles: mongo | backend | frontend | monitoreo

set -e

ROLE=$1
NAMESPACE="luis-felipe-09-namespace"
REPO_DIR="/home/ubuntu/examen-manifiestos"

log() { echo "[$(date +'%H:%M:%S')] $*"; }

# Validar rol
case "$ROLE" in
    mongo|backend|frontend|monitoreo) ;;
    *) echo "Uso: $0 {mongo|backend|frontend|monitoreo}"; exit 1 ;;
esac

log "Iniciando Minikube..."
minikube start --driver=docker --memory=2048mb 2>/dev/null || true
log "Minikube listo"

# Esperar a que exista el archivo de manifiestos
if [ ! -d "$REPO_DIR" ]; then
    log "ERROR: No se encuentra $REPO_DIR"
    log "Clona el repo primero: git clone https://github.com/FelipeLevanoV/examen-manifiestos.git"
    exit 1
fi

cd "$REPO_DIR"

case "$ROLE" in
    mongo)
        log "Desplegando MongoDB + Exporter..."
        kubectl apply -f mongo-cluster/luis-felipe-09-namespace.yaml
        kubectl apply -f mongo-cluster/mongo-deployment.yaml
        kubectl apply -f mongo-cluster/mongo-service.yaml
        kubectl apply -f mongo-cluster/mongodb-exporter-service.yaml
        kubectl wait --for=condition=ready pod -l app=mongo -n "$NAMESPACE" --timeout=120s
        nohup kubectl port-forward -n "$NAMESPACE" service/mongo-service 27017:27017 --address 0.0.0.0 > /dev/null 2>&1 &
        nohup kubectl port-forward -n "$NAMESPACE" service/mongodb-exporter-service 30092:9216 --address 0.0.0.0 > /dev/null 2>&1 &
        ;;

    backend)
        log "Desplegando Backend..."
        kubectl apply -f backend-cluster/luis-felipe-09-namespace.yaml
        kubectl apply -f backend-cluster/backend-deployment.yaml
        kubectl apply -f backend-cluster/backend-service.yaml
        kubectl wait --for=condition=ready pod -l app=luis-felipe-09-deployment -n "$NAMESPACE" --timeout=120s
        nohup kubectl port-forward -n "$NAMESPACE" service/luis-felipe-09-service 30001:30001 --address 0.0.0.0 > /dev/null 2>&1 &
        ;;

    frontend)
        log "Desplegando Frontend..."
        kubectl apply -f frontend-cluster/luis-felipe-09-namespace.yaml
        kubectl apply -f frontend-cluster/frontend-deployment.yaml
        kubectl apply -f frontend-cluster/frontend-service.yaml
        kubectl wait --for=condition=ready pod -l app=frontend -n "$NAMESPACE" --timeout=120s
        nohup kubectl port-forward -n "$NAMESPACE" service/frontend-service 30080:80 --address 0.0.0.0 > /dev/null 2>&1 &
        ;;

    monitoreo)
        log "Desplegando Prometheus + Grafana..."
        kubectl apply -f monitoreo/namespace-monitoreo.yaml
        kubectl apply -f monitoreo/prometheus/prometheus-config.yaml
        kubectl apply -f monitoreo/prometheus/prometheus-deployment.yaml
        kubectl apply -f monitoreo/prometheus/prometheus-service.yaml
        kubectl apply -f monitoreo/grafana/grafana-datasource.yaml
        kubectl apply -f monitoreo/grafana/grafana-dashboard-configmap.yaml
        kubectl apply -f monitoreo/grafana/grafana-deployment.yaml
        kubectl apply -f monitoreo/grafana/grafana-service.yaml
        kubectl wait --for=condition=ready pod -l app=prometheus -n monitoreo --timeout=60s
        kubectl wait --for=condition=ready pod -l app=grafana -n monitoreo --timeout=60s
        nohup kubectl port-forward -n monitoreo service/prometheus-service 30090:9090 --address 0.0.0.0 > /dev/null 2>&1 &
        nohup kubectl port-forward -n monitoreo service/grafana-service 30300:3000 --address 0.0.0.0 > /dev/null 2>&1 &
        ;;
esac

log "Despliegue completado para rol: $ROLE"
