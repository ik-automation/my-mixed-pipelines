local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;

local customRouteSLIs = [
  {
    name: 'server_route_manifest_reads',
    description: |||
      All read-requests (HEAD or GET) for the manifest endpoints on
      the registry.
      Fetch the manifest identified by name and reference where reference can be
      a tag or digest. A HEAD request can also be issued to this endpoint to
      obtain resource information without receiving all data.
    |||,
    satisfiedThreshold: 0.5,
    toleratedThreshold: 1,
    route: '/v2/{name}/manifests/{reference}',
    methods: ['get', 'head'],
  },
  {
    name: 'server_route_manifest_writes',
    description: |||
      All write-requests (put, delete) for the manifest endpoints on
      the registry.

      Put the manifest identified by name and reference where reference can be
      a tag or digest.

      Delete the manifest identified by name and reference. Note that a manifest
      can only be deleted by digest.
    |||,
    satisfiedThreshold: 10,
    toleratedThreshold: 25,
    route: '/v2/{name}/manifests/{reference}',
    // POST and PATCH are currently unused, but to avoid ignoring them if they
    // were introduced, we include them here.
    methods: ['put', 'delete', 'post', 'patch'],
  },
];

local defaultRegistrySLIProperties = {
  userImpacting: true,
  featureCategory: 'container_registry',
};

local registryBaseSelector = {
  type: 'registry',
};

local registryApdex(selector, satisfiedThreshold, toleratedThreshold=null) =
  histogramApdex(
    histogram='registry_http_request_duration_seconds_bucket',
    selector=registryBaseSelector + selector,
    satisfiedThreshold=satisfiedThreshold,
    toleratedThreshold=toleratedThreshold,
  );

local mainApdex =
  local customizedRoutes = std.set(std.map(function(routeConfig) routeConfig.route, customRouteSLIs));
  local withoutCustomizedRouteSelector = {
    route: { nre: std.join('|', customizedRoutes) },
  };

  registryApdex(withoutCustomizedRouteSelector, satisfiedThreshold=2.5, toleratedThreshold=25);

local sliFromConfig(config) =
  local selector = {
    route: { eq: config.route },
    method: { re: std.join('|', config.methods) },
  };
  local toleratedThreshold =
    if std.objectHas(config, 'toleratedThreshold') then
      config.toleratedThreshold
    else
      null;

  defaultRegistrySLIProperties {
    description: config.description,
    apdex: registryApdex(selector, config.satisfiedThreshold, toleratedThreshold),
    requestRate: rateMetric(
      counter='registry_http_request_duration_seconds_count',
      selector=selector
    ),
    significantLabels: ['method', 'migration_path'],
  };

local customRouteApdexes =
  std.foldl(
    function(memo, sliConfig) memo { [sliConfig.name]: sliFromConfig(sliConfig) },
    customRouteSLIs,
    {}
  );

{
  /*
   * This returns the base selector for the registry
   * { type: 'registry' }
   * To be used as a promql selector.
   * This allows the same selector to be for other SLIs.
   */
  registryBaseSelector:: registryBaseSelector,

  /*
   * These properties are the properties that can be reused in all registry SLIs
   *
   */
  defaultRegistrySLIProperties:: defaultRegistrySLIProperties,

  /*
   * This apdex contains of the routes that do not have a customized apdex
   * When adding routes to the customApdexRouteConfig, they will get excluded
   * from this one.
   */
  mainApdex:: mainApdex,

  /*
   * This contains an apdex for all of the routes-method combinations that have
   * a custom configuration
   */
  apdexPerRoute:: customRouteApdexes,

  /*
  *
  * Returns the unmodified config, this is used in tests to validate that all
  * methods for routes are defined
  */
  customApdexRouteConfig:: customRouteSLIs,
}
