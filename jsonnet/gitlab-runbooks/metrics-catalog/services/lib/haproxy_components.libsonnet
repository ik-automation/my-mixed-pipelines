local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;

local defaultHTTPSLIDescription = |||
  Measures aggregated HTTP request traffic through the HAProxy.
  5xx responses are considered to be failures.
|||;

local defaultL4SLIDescription = |||
  Measures aggregated L4 traffic through the HAProxy. Traffic is measured in TCP connections,
  with upstream TCP connection failures being treated as service-level failures.
|||;

local singleHTTPComponent(stage, selector, definition, userImpacting) =
  local backends = definition.backends;
  local toolingLinks = definition.toolingLinks;
  local baseSelector = selector {
    backend: if std.length(backends) == 1 then backends[0] else { re: std.join('|', backends) },
  };

  metricsCatalog.serviceLevelIndicatorDefinition({
    userImpacting: userImpacting,

    staticLabels: {
      stage: stage,
    },

    requestRate: rateMetric(
      counter='haproxy_backend_http_responses_total',
      selector=baseSelector
    ),

    errorRate: rateMetric(
      counter='haproxy_backend_http_responses_total',
      selector=baseSelector { code: '5xx' }
    ),

    significantLabels: [],

    toolingLinks: toolingLinks,
  });

// This is for opaque HTTPS-to-HTTPS or SSH proxying, specifically for pages/git etc
local singleL4Component(stage, selector, definition, userImpacting) =
  local backends = definition.backends;
  local toolingLinks = definition.toolingLinks;

  local baseSelector = selector {
    backend: if std.length(backends) == 1 then backends[0] else { re: std.join('|', backends) },
  };

  metricsCatalog.serviceLevelIndicatorDefinition({
    userImpacting: userImpacting,
    trafficCessationAlertConfig: false,  // Only monitor this at the combined level
    staticLabels: {
      stage: stage,
    },

    requestRate: rateMetric(
      counter='haproxy_server_sessions_total',
      selector=baseSelector
    ),

    errorRate: rateMetric(
      counter='haproxy_server_connection_errors_total',
      selector=baseSelector
    ),

    significantLabels: [],

    toolingLinks: toolingLinks,
  });

local combinedBackendCurry(generator, defaultSLIDescription, trafficCessationAlertConfig) =
  function(userImpacting, stageMappings, selector, featureCategory, team=null, description=defaultSLIDescription, regional=null, dependsOn=[])
    metricsCatalog.combinedServiceLevelIndicatorDefinition(
      userImpacting=userImpacting,
      featureCategory=featureCategory,
      team=team,
      description=description,
      trafficCessationAlertConfig=trafficCessationAlertConfig,
      components=[
        generator(stage=stage, selector=selector, definition=stageMappings[stage], userImpacting=userImpacting)
        for stage in std.objectFields(stageMappings)
      ],
      // Don't double-up RPS by including loadbalancer again
      serviceAggregation=false,
      regional=regional,
      dependsOn=dependsOn
    );


{
  // This returns a combined component mapping, one for each stage (main, cny etc)
  // The mapping is as follows:
  // stageMappings={
  //   main: { backends: ["backend_1", "backend_2"], toolingLinks: [...] },
  //   cny: { backends: ["backend_3", "backend_4"], toolingLinks: [...] },
  // },
  haproxyHTTPLoadBalancer:: combinedBackendCurry(singleHTTPComponent, defaultSLIDescription=defaultHTTPSLIDescription, trafficCessationAlertConfig=true),

  // This returns a combined component mapping, one for each stage (main, cny etc)
  // The mapping is as follows:
  // stageMappings={
  //   main: { backends: ["backend_1", "backend_2"], toolingLinks: [...] },
  //   cny: { backends: ["backend_3", "backend_4"], toolingLinks: [...] },
  // },
  haproxyL4LoadBalancer:: combinedBackendCurry(singleL4Component, defaultSLIDescription=defaultL4SLIDescription, trafficCessationAlertConfig=true),
}
