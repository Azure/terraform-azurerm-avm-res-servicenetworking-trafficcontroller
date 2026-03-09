# Application Gateway for Containers

This is the Terraform AVM (Azure Verified Modules) resource module for **Application Gateway for Containers** (`Microsoft.ServiceNetworking/trafficControllers`).

Application Gateway for Containers is an application (layer 7) load balancing and dynamic traffic management product for workloads running in a Kubernetes cluster. It extends Azure's Application Load Balancing portfolio and is a new offering under the Application Gateway product family.

> [!IMPORTANT]
> As the overall AVM framework is not GA (generally available) yet - the CI framework and target for AVM for Terraform Modules is **Terraform `~> 1.9`**

## Features

- Deploys an Application Gateway for Containers (Traffic Controller) resource using the AzAPI provider.
- Supports resource locks (`CanNotDelete`, `ReadOnly`).
- Supports role assignments on the Traffic Controller resource.
- Supports diagnostic settings for monitoring and logging.
- Supports tags for resource organization.
- Includes AVM telemetry integration.

## Usage

For a basic deployment, see the [default example](./examples/default/).

> For more information, see the [Azure Application Gateway for Containers documentation](https://learn.microsoft.com/en-us/azure/application-gateway/for-containers/overview).
