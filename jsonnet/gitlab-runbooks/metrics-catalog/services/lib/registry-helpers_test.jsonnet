local registryHelpers = import './registry-helpers.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

local allMethodsForRoute(config, route) =
  local allMethods = std.filterMap(
    function(config) config.route == route,
    function(config) config.methods,
    config
  );
  std.set(std.flattenArrays(allMethods));

local missingMethods(config, route) =
  local requiredMethodsPerRoute = std.set(['get', 'head', 'post', 'put', 'delete', 'patch']);
  std.setDiff(requiredMethodsPerRoute, allMethodsForRoute(config, route));

local routesMissingMethods(config) =
  std.foldl(
    function(memo, sli)
      local missing = missingMethods(config, sli.route);
      if std.length(missing) > 0 then
        memo { [sli.route]: missing }
      else
        memo
    , config, {}
  );

local describeMissingMethods(missingMethodsPerRoute) =
  local messages = std.map(
    function(route)
      '%(route)s - [%(methods)s]' % { route: route, methods: std.join(',', missingMethodsPerRoute[route]) },
    std.objectFields(missingMethodsPerRoute)
  );
  std.join('\n', messages);

test.suite({
  testNoMissingMethods: {
    actual: routesMissingMethods(registryHelpers.customApdexRouteConfig),
    expectThat: {
      actual: error 'overridden',
      result: self.actual == {},
      description: 'Methods missing for routes: \n' + describeMissingMethods(self.actual),
    },
  },
})
