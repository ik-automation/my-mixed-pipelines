local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

local environmentSelector = {
  environment: 'ops',
  env: 'ops',
};

serviceDashboard.overview(
  'sentry',
  environmentSelectorHash=environmentSelector,
)
.overviewTrailer()
