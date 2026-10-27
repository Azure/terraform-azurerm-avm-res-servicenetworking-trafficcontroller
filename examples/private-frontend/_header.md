# Private frontend example

This deploys the module with a private frontend by disabling public network access (`public_network_access = "Disabled"`). A private frontend is deployed into the subnet of the association selected with `association_key`, and its FQDN resolves through `privatelink.alb.azure.com`.
