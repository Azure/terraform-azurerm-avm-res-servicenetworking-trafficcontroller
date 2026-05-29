## Post-deployment steps

After Terraform completes, enable the ALB Controller managed add-on and configure Gateway API resources:

```bash
# 1. Enable the ALB Controller add-on on the AKS cluster
az aks update -g <resource_group_name> -n <aks_cluster_name> --enable-alb-controller

# 2. Verify ALB Controller pods are running
az aks command invoke -g <resource_group_name> -n <aks_cluster_name> \
  --command "kubectl get pods -n alb-system"

# 3. Apply Kubernetes Gateway API resources (GatewayClass, Gateway, HTTPRoute)
# See: https://learn.microsoft.com/azure/application-gateway/for-containers/quickstart-create-application-gateway-for-containers-byo-deployment
```

For a consumer with an existing hub-spoke network, replace the inline VNet/subnet resources with references to your existing subnet IDs.
