local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local listDownstreamServicesRecursive(service, foundServices) =
  if std.objectHas(service, 'serviceDependencies') then
    std.foldl(
      function(memo, serviceName)
        if std.setMember(serviceName, memo) then
          memo
        else
          local newFound = std.setUnion(memo, [serviceName]);
          listDownstreamServicesRecursive(metricsCatalog.getService(serviceName), newFound),
      std.objectFields(service.serviceDependencies),
      foundServices
    )
  else
    foundServices;

local listDownstreamServices(serviceName) =
  local service = metricsCatalog.getService(serviceName);
  local foundServices = std.set([serviceName]);
  listDownstreamServicesRecursive(service, foundServices);

{
  listDownstreamServices(serviceName)::
    listDownstreamServices(serviceName),
}
