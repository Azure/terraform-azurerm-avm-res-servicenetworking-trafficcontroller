# Private frontend example

This deploys the module with a private frontend by disabling public network access (`public_network_access = "Disabled"`). A private frontend is deployed into the subnet of the association selected with `association_key`, and its FQDN resolves through `privatelink.alb.azure.com`.

It also uses the `private_endpoints` interface to create a private endpoint for the private frontend. The `subresource_name` of the private endpoint is the name of the private frontend, and the endpoint is registered in a `privatelink.alb.azure.com` private DNS zone linked to the virtual network.
