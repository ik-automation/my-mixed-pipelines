local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local seriesOverrides = import 'grafana/series_overrides.libsonnet';
local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';
local row = grafana.row;
local thresholds = import 'gitlab-dashboards/thresholds.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local metricsConfig = import 'gitlab-metrics-config.libsonnet';
local templates = import 'grafana/templates.libsonnet';

// Preferred ordering of rows on the SLA dashboard
local serviceOrdering = [
  'web',
  'git',
  'api',
  'ci-runners',
  'registry',
  'web-pages',
];

local overviewDashboardLinks(type) =
  local formatConfig = { type: type };
  [
    {
      url: '/d/%(type)s-main/%(type)s-overview?orgId=1&${__url_time_range}' % formatConfig,
      title: '%(type)s service: Overview Dashboard' % formatConfig,
    },
  ];

local thresholdsValues = {
  thresholds: [
    thresholds.errorLevel('lt', metricsConfig.slaTarget),
  ],
};

// Note, by having a overall_sla_weighting value, even if it is zero, the service will
// be included on the SLA dashboard. To remove it, delete the key
local keyServices = serviceCatalog.findKeyBusinessServices(includeZeroScore=true);

local keyServiceSorter(service) =
  local l = std.find(service.name, serviceOrdering);
  if l == [] then
    100
  else
    l[0];

// NB: this query takes into account values recorded in Prometheus prior to
// https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/9689
// Better fix proposed in https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/326
// This is encoded in the `defaultSelector`
local serviceAvailabilityQuery(selectorHash, metricName, rangeInterval) =
  local defaultSelector = {
    env: { re: 'ops|$environment' },
    environment: '$environment',
    stage: '$stage',
    monitor: { re: 'global|' },
  };

  |||
    avg(
      clamp_max(
        avg_over_time(%(metricName)s{%(selector)s}[%(rangeInterval)s]),
        1
      )
    )
  ||| % {
    selector: selectors.serializeHash(defaultSelector + selectorHash),
    metricName: metricName,
    rangeInterval: rangeInterval,
  };

local serviceRow(service) =
  local links = overviewDashboardLinks(service.name);
  [
    basic.slaStats(
      title='',
      query=|||
        (1 - %(budgetExpression)s) * ($__range_ms / (86400000 * 30.5)) * 100 * 100
      ||| % {
        budgetExpression: serviceAvailabilityQuery({ type: service.name }, 'slo_observation_status', '$__range'),
      },
      legendFormat=service.friendly_name + ': Availability Basis Points Spent',
      displayName=service.friendly_name,
      links=links,
      invertColors=true,
      decimals=2,
      unit='',
    ),
    basic.statPanel(
      'Weight',
      '',
      'black',
      '' + service.business.SLA.overall_sla_weighting,
      'Overall Weight',
      instant=false
    ),
    basic.slaTimeseries(
      title='%s: Availability ' % [service.friendly_name],
      description='Rolling average SLO adherence for primary services. Higher is better.',
      yAxisLabel='SLA',
      query=serviceAvailabilityQuery({ type: service.name }, 'slo_observation_status', '$__interval'),
      legendFormat='{{ type }}',
      interval='1m',
      legend_show=false
    )
    .addDataLink(links) + thresholdsValues +
    {
      options: { dataLinks: links },
    },
  ];

local primaryServiceRows = std.map(serviceRow, std.sort(keyServices, keyServiceSorter));

basic.dashboard(
  'Incident Budget Explorer',
  tags=['general', 'slas', 'service-levels'],
  includeStandardEnvironmentAnnotations=false,
  time_from='now-6h/m',
  time_to='now/m',
)
.addTemplate(templates.stage)
.addTemplate(templates.slaType)
.addPanel(
  row.new(title='Overall GitLab.com Availability Points Spent'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.columnGrid([[
    basic.slaStats(
      title='Total GitLab.com Availability Basis Points Spent',
      query=|||
        (1 - %(budgetExpression)s) * ($__range_ms / (86400000 * 30.5)) * 100 * 100
      ||| % {
        budgetExpression: serviceAvailabilityQuery({ sla_type: '$sla_type' }, 'sla:gitlab:ratio', '$__range'),
      },
      invertColors=true,
      decimals=2,
      unit='',
    ),
    basic.slaStats(
      title='Monthly Availability Basis Points Budget',
      query=|||
        (1 - sla:gitlab:target{monitor="global"}) * 100 * 100
      ||| % {
        budgetExpression: serviceAvailabilityQuery({ sla_type: '$sla_type' }, 'sla:gitlab:ratio', '$__range'),
      },
      invertColors=true,
      decimals=0,
      unit='',
    ),
    basic.slaTimeseries(
      title='Availability - gitlab.com',
      description='Rolling average SLO adherence across all primary services. Higher is better.',
      yAxisLabel='SLA',
      query=serviceAvailabilityQuery({ sla_type: '$sla_type' }, 'sla:gitlab:ratio', '$__interval'),
      legendFormat='gitlab.com SLA',
      interval='1m',
      legend_show=false
    )
    .addSeriesOverride(seriesOverrides.goldenMetric('gitlab.com SLA'))
    + thresholdsValues,
  ]], [4, 4, 16], rowHeight=5, startRow=1)
)
.addPanel(
  row.new(title='Primary Services'),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.columnGrid(primaryServiceRows, [6, 2, 16], rowHeight=5, startRow=2101)
)
.trailer()
+ {
  links+: platformLinks.services + platformLinks.triage,
}
