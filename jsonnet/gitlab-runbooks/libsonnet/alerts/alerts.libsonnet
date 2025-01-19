local strings = import 'utils/strings.libsonnet';

local getGrafanaLink(annotations) =
  local dashboardId = annotations.grafana_dashboard_id;
  local zoomHours = annotations.grafana_min_zoom_hours;
  local variables = annotations.grafana_variables;

  local queryParams = [
    'from=now-' + zoomHours + 'h/m',
    'to=now-1m/m',
  ] + [
    'var-%(v)s={{ $labels.%(v)s }}' % { v: v }
    for v in std.split(variables, ',')
  ];
  'https://dashboards.gitlab.net/d/' + dashboardId + '?' + std.join('&', queryParams);

local ensureObjectHasStringValues(hash) =
  std.foldl(
    function(memo, key)
      memo { [if hash[key] != null then key]: std.toString(hash[key]) },
    std.objectFields(hash),
    {}
  );

local unwrapNewlinesForAnnotationKey(key, value) =
  if key == 'title' || key == 'description' then
    strings.unwrapText(value)
  else
    value;

local unwrapNewlinesOnAnnotations(hash) =
  std.foldl(
    function(memo, key)
      memo { [key]: unwrapNewlinesForAnnotationKey(key, hash[key]) },
    std.objectFields(hash),
    {}
  );

{
  processAlertRule(alertRule)::
    local annotations = alertRule.annotations +
                        if std.objectHas(alertRule.annotations, 'grafana_dashboard_id') then
                          {
                            grafana_dashboard_link: getGrafanaLink(alertRule.annotations),
                          }
                        else
                          {};

    // The Prometheus Operator doesn't like label values that are not strings
    alertRule {
      annotations: ensureObjectHasStringValues(unwrapNewlinesOnAnnotations(annotations)),
      labels: ensureObjectHasStringValues(alertRule.labels),
    },

  // Utility for processing lots of rules in an array
  processAlertRules(alertRules)::
    std.map(self.processAlertRule, alertRules),
}
