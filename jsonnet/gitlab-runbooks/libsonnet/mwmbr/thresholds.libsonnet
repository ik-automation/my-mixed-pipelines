local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local namedThreshold(name) = {
  name: name,

  // These are the SLO metrics that will be used for recording health
  errorSLO: 'slo:max:%(name)s:gitlab_service_errors:ratio' % { name: name },
  apdexSLO: 'slo:min:%(name)s:gitlab_service_apdex:ratio' % { name: name },

  // These health metrics wil be 1 when the SLO is above the threshold for
  // the burnrates defined in mwbr/expression.libsonnet
  errorHealth: 'gitlab_%(name)s_health:service:errors' % { name: name },
  apdexHealth: 'gitlab_%(name)s_health:service:apdex' % { name: name },

  // These will aggregate the health metrics across service or stage
  aggregateServiceHealth: 'gitlab_%(name)s_health:service' % { name: name },
  aggregateStageHealth: 'gitlab_%(name)s_health:stage' % { name: name },
};

local thresholdsForService(service) =
  if std.objectHas(service, 'otherThresholds') then
    std.map(namedThreshold, std.objectFields(service.otherThresholds))
  else
    [];

{
  namedThreshold(name):: namedThreshold(name),
  knownOtherThresholds::
    std.set(
      std.flatMap(thresholdsForService, metricsCatalog.services),
      keyF=function(threshold) threshold.name
    ),
}
