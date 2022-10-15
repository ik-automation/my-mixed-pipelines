local services = (import 'gitlab-metrics-config.libsonnet').monitoredServices;
local saturationResource = import './saturation-resources.libsonnet';

// Index services by `type`
local serviceMap = std.foldl(function(running, service) running { [service.type]: service }, services, {});

// Filter services with a predicate, and ensure that defaultType is first.
local findServiceTypesWithFirst(defaultType, predicate) =
  std.foldl(
    function(memo, s)
      if predicate(s) then
        if s.type == defaultType then
          // prefix...
          [s.type] + memo
        else
          // postfix...
          memo + [s.type]
      else
        memo,
    services,
    []
  );

local serviceApplicableSaturationTypes(service)
      = saturationResource.listApplicableServicesFor(service.type);

{
  services:: services,

  // Find a service for the given service type
  getService(serviceType)::
    local service = serviceMap[serviceType];
    service {
      applicableSaturationTypes():: serviceApplicableSaturationTypes(service),
    },

  findServicesExcluding(first=null, excluding)::
    findServiceTypesWithFirst(first, function(s) !std.setMember(s.type, excluding)),

  findServicesWithTag(first=null, tag)::
    findServiceTypesWithFirst(first, function(s) std.setMember(tag, s.tags)),

  findKubeProvisionedServices(first=null)::
    findServiceTypesWithFirst(first, function(s) s.provisioning.kubernetes),

  findKubeOnlyServices(first=null)::
    findServiceTypesWithFirst(first, function(s) s.provisioning.kubernetes && !s.provisioning.vms),

  findVMProvisionedServices(first=null)::
    findServiceTypesWithFirst(first, function(s) s.provisioning.vms),

  // Returns a list of all services that are provisioned on kubernetes that
  // also have dedicated node pools
  findKubeProvisionedServicesWithDedicatedNodePool(first=null)::
    findServiceTypesWithFirst(first, function(s) s.hasDedicatedKubeNodePool()),

  serviceExists(serviceType)::
    std.objectHas(serviceMap, serviceType),
}
