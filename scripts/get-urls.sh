#!/bin/bash

# Get URLs script for Dependency Track services
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_url() {
    echo -e "${BLUE}[URL]${NC} $1"
}

usage() {
    echo "Usage: $0 [ENVIRONMENT] [OPTIONS]"
    echo ""
    echo "Environments:"
    echo "  dev          Get URLs for dev environment"
    echo "  prod         Get URLs for prod environment"
    echo "  all          Get URLs for all environments"
    echo ""
    echo "Options:"
    echo "  --port-forward    Enable port-forwarding for local access"
    echo "  --ingress        Show ingress URLs (if available)"
    echo "  --help           Show this help message"
}

check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
}

get_service_urls() {
    local env=$1
    local namespace="dependency-track-$env"
    local port_forward=${2:-false}
    local show_ingress=${3:-false}
    
    log_info "Getting service URLs for $env environment (namespace: $namespace)"
    echo ""
    
    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        log_error "Namespace $namespace does not exist"
        return 1
    fi
    
    # Get services
    local services=$(kubectl get services -n "$namespace" --no-headers -o custom-columns=":metadata.name")
    
    if [[ -z "$services" ]]; then
        log_warn "No services found in namespace $namespace"
        return 1
    fi
    
    echo "Services in $namespace:"
    echo "========================"
    
    for service in $services; do
        local service_type=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.spec.type}')
        local ports=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.spec.ports[*].port}')
        local target_ports=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.spec.ports[*].targetPort}')
        
        echo ""
        echo "Service: $service"
        echo "Type: $service_type"
        echo "Ports: $ports"
        echo "Target Ports: $target_ports"
        
        case $service_type in
            "ClusterIP")
                log_url "Internal URL: http://$service.$namespace.svc.cluster.local:$(echo $ports | cut -d' ' -f1)"
                
                if [[ "$port_forward" == "true" ]]; then
                    local local_port=$((8080 + $(echo $env | wc -c)))
                    if [[ "$service" == *"frontend"* ]]; then
                        local_port=$((3000 + $(echo $env | wc -c)))
                    elif [[ "$service" == *"database"* ]]; then
                        local_port=$((5432 + $(echo $env | wc -c)))
                    fi
                    
                    log_info "To access locally, run:"
                    echo "  kubectl port-forward service/$service -n $namespace $local_port:$(echo $ports | cut -d' ' -f1)"
                    log_url "Local URL: http://localhost:$local_port"
                fi
                ;;
            "NodePort")
                local node_port=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.spec.ports[0].nodePort}')
                local node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
                if [[ -z "$node_ip" ]]; then
                    node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
                fi
                log_url "NodePort URL: http://$node_ip:$node_port"
                ;;
            "LoadBalancer")
                local lb_ip=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                local lb_hostname=$(kubectl get service "$service" -n "$namespace" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                
                if [[ -n "$lb_ip" ]]; then
                    log_url "LoadBalancer URL: http://$lb_ip:$(echo $ports | cut -d' ' -f1)"
                elif [[ -n "$lb_hostname" ]]; then
                    log_url "LoadBalancer URL: http://$lb_hostname:$(echo $ports | cut -d' ' -f1)"
                else
                    log_warn "LoadBalancer IP/hostname not yet assigned"
                fi
                ;;
        esac
    done
    
    # Check for ingresses
    if [[ "$show_ingress" == "true" ]]; then
        echo ""
        echo "Ingresses in $namespace:"
        echo "======================="
        
        local ingresses=$(kubectl get ingresses -n "$namespace" --no-headers -o custom-columns=":metadata.name" 2>/dev/null || echo "")
        
        if [[ -n "$ingresses" ]]; then
            for ingress in $ingresses; do
                local hosts=$(kubectl get ingress "$ingress" -n "$namespace" -o jsonpath='{.spec.rules[*].host}')
                local paths=$(kubectl get ingress "$ingress" -n "$namespace" -o jsonpath='{.spec.rules[*].http.paths[*].path}')
                
                echo ""
                echo "Ingress: $ingress"
                
                for host in $hosts; do
                    for path in $paths; do
                        log_url "https://$host$path"
                    done
                done
            done
        else
            log_info "No ingresses found"
        fi
    fi
    
    # Show pods status
    echo ""
    echo "Pod Status in $namespace:"
    echo "========================"
    kubectl get pods -n "$namespace" -o wide
}

show_all_environments() {
    local port_forward=$1
    local show_ingress=$2
    
    for env in dev prod; do
        echo ""
        echo "=========================================="
        get_service_urls "$env" "$port_forward" "$show_ingress"
        echo "=========================================="
    done
}

# Main script
main() {
    check_prerequisites
    
    local environment=${1:-all}
    local port_forward=false
    local show_ingress=false
    
    # Parse flags
    shift || true
    while [[ $# -gt 0 ]]; do
        case $1 in
            --port-forward)
                port_forward=true
                shift
                ;;
            --ingress)
                show_ingress=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    case $environment in
        dev|prod)
            get_service_urls "$environment" "$port_forward" "$show_ingress"
            ;;
        all)
            show_all_environments "$port_forward" "$show_ingress"
            ;;
        *)
            log_error "Unknown environment: $environment"
            usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi