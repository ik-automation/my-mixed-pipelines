local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';

// Preferred ordering services on dashboards
local serviceOrdering = [
  'web',
  'git',
  'api',
  'ci-runners',
  'registry',
  'web-pages',
];

local keyServiceSorter(service) =
  local l = std.find(service.name, serviceOrdering);
  if l == [] then
    100
  else
    l[0];

{
  // Note, by having a overall_sla_weighting value, even if it is zero, the service will
  // be included on the SLA and MTBF dashboards. To remove it, delete the key
  keyServices::
    serviceCatalog.findKeyBusinessServices(includeZeroScore=true),

  sortedKeyServices::
    std.sort(self.keyServices, keyServiceSorter),
}
