#!/bin/bash
# Kubernetes deployment script for Insurebook Rails application

set -e

# Configuration
NAMESPACE="insurebook"
REGISTRY="your-registry.com"
IMAGE_NAME="insurebook"
VERSION=${1:-latest}
ENVIRONMENT=${2:-production}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if kubectl is installed and configured
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi

    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Unable to connect to Kubernetes cluster"
        exit 1
    fi

    # Check if Docker is running (for image building)
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Create namespace if it doesn't exist
create_namespace() {
    log_info "Creating namespace: $NAMESPACE"

    if kubectl get namespace $NAMESPACE &> /dev/null; then
        log_info "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace $NAMESPACE
        kubectl label namespace $NAMESPACE environment=$ENVIRONMENT
        log_success "Namespace $NAMESPACE created"
    fi
}

# Build and push Docker image
build_and_push_image() {
    log_info "Building Docker image..."

    # Build the image
    docker build -t $REGISTRY/$IMAGE_NAME:$VERSION .
    docker tag $REGISTRY/$IMAGE_NAME:$VERSION $REGISTRY/$IMAGE_NAME:latest

    log_info "Pushing Docker image to registry..."
    docker push $REGISTRY/$IMAGE_NAME:$VERSION
    docker push $REGISTRY/$IMAGE_NAME:latest

    log_success "Docker image built and pushed"
}

# Create secrets (if they don't exist)
create_secrets() {
    log_info "Checking secrets..."

    if ! kubectl get secret rails-secrets -n $NAMESPACE &> /dev/null; then
        log_warning "rails-secrets not found. Please create it manually:"
        log_warning "kubectl create secret generic rails-secrets \\"
        log_warning "  --from-literal=database-url='postgresql://user:pass@host:5432/db' \\"
        log_warning "  --from-literal=redis-url='redis://host:6379/0' \\"
        log_warning "  --from-literal=rails-master-key='your_master_key' \\"
        log_warning "  --namespace=$NAMESPACE"

        read -p "Continue without secrets? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

# Apply Kubernetes manifests
apply_manifests() {
    log_info "Applying Kubernetes manifests..."

    # Apply in correct order
    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f k8s/configmap.yaml
    kubectl apply -f k8s/secrets.yaml || log_warning "Secrets file skipped (may contain templates)"

    # Storage
    kubectl apply -f k8s/postgres.yaml
    kubectl apply -f k8s/redis.yaml

    # Wait for storage to be ready
    log_info "Waiting for database to be ready..."
    kubectl wait --for=condition=ready pod -l app=insurebook,component=postgres -n $NAMESPACE --timeout=300s

    log_info "Waiting for Redis to be ready..."
    kubectl wait --for=condition=ready pod -l app=insurebook,component=redis -n $NAMESPACE --timeout=300s

    # Update image in manifests
    sed -i.bak "s|your-registry.com/insurebook:latest|$REGISTRY/$IMAGE_NAME:$VERSION|g" k8s/rails-app.yaml
    sed -i.bak "s|your-registry.com/insurebook:latest|$REGISTRY/$IMAGE_NAME:$VERSION|g" k8s/sidekiq.yaml

    # Application
    kubectl apply -f k8s/rails-app.yaml
    kubectl apply -f k8s/sidekiq.yaml
    kubectl apply -f k8s/ingress.yaml

    # Restore original files
    mv k8s/rails-app.yaml.bak k8s/rails-app.yaml
    mv k8s/sidekiq.yaml.bak k8s/sidekiq.yaml

    log_success "Manifests applied successfully"
}

# Wait for deployment to be ready
wait_for_deployment() {
    log_info "Waiting for deployments to be ready..."

    # Wait for Rails app
    kubectl wait --for=condition=progressing deployment/rails-app -n $NAMESPACE --timeout=300s
    kubectl wait --for=condition=available deployment/rails-app -n $NAMESPACE --timeout=600s

    # Wait for Sidekiq
    kubectl wait --for=condition=available deployment/sidekiq -n $NAMESPACE --timeout=300s

    log_success "All deployments are ready"
}

# Run database migrations
run_migrations() {
    log_info "Running database migrations..."

    # Find a rails pod
    RAILS_POD=$(kubectl get pods -n $NAMESPACE -l component=rails-app -o jsonpath='{.items[0].metadata.name}')

    if [ -z "$RAILS_POD" ]; then
        log_error "No Rails pods found"
        exit 1
    fi

    # Run migrations
    kubectl exec -n $NAMESPACE $RAILS_POD -- bundle exec rails db:migrate

    log_success "Database migrations completed"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."

    # Check pod status
    echo
    log_info "Pod status:"
    kubectl get pods -n $NAMESPACE -o wide

    # Check services
    echo
    log_info "Services:"
    kubectl get services -n $NAMESPACE

    # Check ingress
    echo
    log_info "Ingress:"
    kubectl get ingress -n $NAMESPACE

    # Test health endpoint
    echo
    log_info "Testing health endpoint..."
    RAILS_POD=$(kubectl get pods -n $NAMESPACE -l component=rails-app -o jsonpath='{.items[0].metadata.name}')

    if kubectl exec -n $NAMESPACE $RAILS_POD -- curl -f http://localhost:3000/health &> /dev/null; then
        log_success "Health check passed"
    else
        log_warning "Health check failed"
    fi

    echo
    log_success "Deployment verification completed"
}

# Rollback deployment
rollback_deployment() {
    log_info "Rolling back deployment..."

    kubectl rollout undo deployment/rails-app -n $NAMESPACE
    kubectl rollout undo deployment/sidekiq -n $NAMESPACE

    kubectl rollout status deployment/rails-app -n $NAMESPACE
    kubectl rollout status deployment/sidekiq -n $NAMESPACE

    log_success "Rollback completed"
}

# Show logs
show_logs() {
    echo
    log_info "Recent logs from Rails application:"
    kubectl logs -n $NAMESPACE deployment/rails-app --tail=50

    echo
    log_info "Recent logs from Sidekiq:"
    kubectl logs -n $NAMESPACE deployment/sidekiq --tail=50
}

# Cleanup function
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f k8s/*.yaml.bak
}

# Trap cleanup
trap cleanup EXIT

# Main deployment function
deploy() {
    log_info "Starting deployment of $IMAGE_NAME:$VERSION to $ENVIRONMENT environment"

    check_prerequisites
    create_namespace
    build_and_push_image
    create_secrets
    apply_manifests
    wait_for_deployment
    run_migrations
    verify_deployment

    log_success "Deployment completed successfully!"
    log_info "Your application should be available at the configured ingress endpoint"
}

# CLI interface
case "${1:-deploy}" in
    "deploy")
        deploy
        ;;
    "rollback")
        rollback_deployment
        ;;
    "logs")
        show_logs
        ;;
    "verify")
        verify_deployment
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [command] [version] [environment]"
        echo ""
        echo "Commands:"
        echo "  deploy    - Deploy application (default)"
        echo "  rollback  - Rollback to previous version"
        echo "  logs      - Show application logs"
        echo "  verify    - Verify current deployment"
        echo "  help      - Show this help"
        echo ""
        echo "Examples:"
        echo "  $0 deploy v1.2.0 production"
        echo "  $0 rollback"
        echo "  $0 logs"
        ;;
    *)
        VERSION=$1
        ENVIRONMENT=${2:-production}
        deploy
        ;;
esac