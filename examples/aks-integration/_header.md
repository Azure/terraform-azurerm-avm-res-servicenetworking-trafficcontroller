# Application Gateway for Containers with AKS — BYO Deployment

This example deploys Application Gateway for Containers alongside a private AKS cluster using the Bring Your Own (BYO) deployment strategy. It demonstrates the recommended Azure infrastructure setup based on the [AKS Secure Baseline Private Cluster](https://github.com/Azure/AKS-Landing-Zone-Accelerator/tree/main/Scenarios/AKS-Secure-Baseline-PrivateCluster) pattern.

## What this deploys

- **Virtual Network** with three subnets: AKS nodes, AG4C association (delegated), and API server VNet integration (delegated)
- **AKS Private Cluster** with Azure CNI, Workload Identity, and OIDC issuer enabled
- **Application Gateway for Containers** with one frontend and one association
- **User-Assigned Managed Identity** with the required RBAC roles for the ALB Controller
