package Azure_Proactive_Resiliency_Library_v2

import rego.v1

# The AKS cluster is deployed via the AVM managed cluster module, which builds
# `agentPoolProfiles` as a computed list containing the (known-after-apply)
# `vnetSubnetID`. As a result the whole `agentPoolProfiles` block is unknown at
# plan time, so these policies cannot read the `availabilityZones` /
# `enableAutoScaling` values even though the example configures auto scaling.
# These rules are therefore excepted, mirroring the AVM managed cluster module's
# own default example.
exception contains rules if {
  rules = ["configure_aks_default_node_pool_zones", "aks_enable_cluster_autoscaler"]
}
