local keyMetrics = import 'gitlab-dashboards/key_metrics.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local selector = { stage: 'main', env: '$environment', environment: '$environment' };

local playlistDefinitions = {
  'frontend-rails': {
    title: 'Rails Services',
    services: [
      'web',
      'api',
      'git',
      'sidekiq',
      'websockets',
    ],
  },
  'frontend-aux': {
    title: 'Other Services',
    services: [
      'ci-runners',
      'registry',
      'web-pages',
      'camoproxy',
    ],
  },
  storage: {
    title: 'Storage',
    services: [
      'gitaly',
      'praefect',
    ],
  },
  database: {
    title: 'Databases',
    services: [
      'redis',
      'redis-cache',
      'redis-sidekiq',
      'patroni',
      'pgbouncer',
    ],
  },

};

local panelsForService(index, serviceType) =
  local service = metricsCatalog.getService(serviceType);
  keyMetrics.headlineMetricsRow(
    serviceType,
    startRow=1000 + index * 100,
    rowTitle=null,
    selectorHash=selector,
    stableIdPrefix=serviceType,
    showApdex=service.hasApdex(),
    showErrorRatio=service.hasErrorRate(),
    compact=true,
    rowHeight=6,
    showDashboardListPanel=true,
  );

{
  ['playlist-' + playlistName]:
    local playlist = playlistDefinitions[playlistName];
    local panels = std.flattenArrays(
      std.mapWithIndex(panelsForService, playlist.services)
    );
    basic.dashboard(
      'Triage Playlist: ' + playlist.title,
      tags=['general'],
    )
    .addPanels(panels)
    .trailer()
  for playlistName in std.objectFields(playlistDefinitions)
}
