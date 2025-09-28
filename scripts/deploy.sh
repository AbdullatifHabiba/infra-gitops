#!/bin/bash

# Dependency Track GitOps Deployment Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

usage() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  deploy-project     Deploy the ArgoCD project"
    echo "  deploy-dev        Deploy dev environment"
    echo "  deploy-prod       Deploy prod environment"
    echo "  deploy-all        Deploy project and all environments"
    echo "  sync-dev          Sync dev application"
    echo "  sync-prod         Sync prod application"
    echo "  status            Show status of all applications"
    echo "  help              Show this help message"
    echo ""
    echo "Options:"
    echo "  --dry-run         Show what would be deployed without actually doing it"
    echo "  --wait            Wait for sync to complete"
}

check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi

    if ! command -v argocd &> /dev/null; then
        log_warn "argocd CLI is not installed. Some features may not work."
    fi
}

deploy_project() {
    local dry_run=${1:-false}
    
    log_info "Deploying ArgoCD project..."
    
    if [[ "$dry_run" == "true" ]]; then
        kubectl apply --dry-run=client -f "$PROJECT_ROOT/argo-apps/project.yaml"
    else
        kubectl apply -f "$PROJECT_ROOT/argo-apps/project.yaml"
        log_info "ArgoCD project deployed successfully"
    fi
}

deploy_environment() {
    local env=$1
    local dry_run=${2:-false}
    local wait=${3:-false}
    
    log_info "Deploying $env environment..."
    
    if [[ "$dry_run" == "true" ]]; then
        kubectl apply --dry-run=client -f "$PROJECT_ROOT/argo-apps/dependency-track-$env.yaml"
    else
        kubectl apply -f "$PROJECT_ROOT/argo-apps/dependency-track-$env.yaml"
        
        if [[ "$wait" == "true" ]]; then
            log_info "Waiting for $env application to sync..."
            kubectl wait --for=condition=Synced --timeout=600s application/dependency-track-$env -n argocd || log_warn "Sync timeout for $env environment"
        fi
        
        log_info "$env environment deployed successfully"
    fi
}

sync_application() {
    local env=$1
    local wait=${2:-false}
    
    if command -v argocd &> /dev/null; then
        log_info "Syncing $env application..."
        argocd app sync dependency-track-$env
        
        if [[ "$wait" == "true" ]]; then
            argocd app wait dependency-track-$env --timeout 600
        fi
    else
        log_warn "argocd CLI not available. Use kubectl to patch the application for manual sync."
        kubectl patch application dependency-track-$env -n argocd -p '{"operation":{"sync":{}}}' --type=merge
    fi
}

show_status() {
    log_info "Application Status:"
    
    if command -v argocd &> /dev/null; then
        argocd app list | grep dependency-track
        echo ""
        argocd app get dependency-track-dev --show-params
        echo ""
        argocd app get dependency-track-prod --show-params
    else
        kubectl get applications -n argocd | grep dependency-track
        kubectl get applications dependency-track-dev dependency-track-prod -n argocd -o wide
    fi
}

# Main script
main() {
    check_prerequisites
    
    local command=${1:-help}
    local dry_run=false
    local wait=false
    
    # Parse flags
    shift
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                dry_run=true
                shift
                ;;
            --wait)
                wait=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    case $command in
        deploy-project)
            deploy_project "$dry_run"
            ;;
        deploy-dev)
            deploy_environment "dev" "$dry_run" "$wait"
            ;;
        deploy-prod)
            deploy_environment "prod" "$dry_run" "$wait"
            ;;
        deploy-all)
            deploy_project "$dry_run"
            deploy_environment "dev" "$dry_run" "$wait"
            deploy_environment "prod" "$dry_run" "$wait"
            ;;
        sync-dev)
            sync_application "dev" "$wait"
            ;;
        sync-prod)
            sync_application "prod" "$wait"
            ;;
        status)
            show_status
            ;;
        help|*)
            usage
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi