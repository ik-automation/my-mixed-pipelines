local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local timepickerlib = import 'github.com/grafana/grafonnet-lib/grafonnet/timepicker.libsonnet';
local prometheus = grafana.prometheus;
local promQuery = import 'grafana/prom_query.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local annotation = grafana.annotation;
local graphPanel = grafana.graphPanel;
local statPanel = grafana.statPanel;
local row = grafana.row;

local environments = [
  {
    id: 'gprd',
    name: 'Production',
    role: 'gprd',
    stage: 'main',
    icon: '🚀',
  },
  {
    id: 'gprd-cny',
    name: 'Canary',
    role: 'gprd',
    stage: 'cny',
    icon: '🐤',
  },
  {
    id: 'gstg',
    name: 'Staging',
    role: 'gstg',
    stage: 'main',
    icon: '🏗',
  },
  {
    id: 'gstg-cny',
    name: 'Staging Canary',
    role: 'gstg',
    stage: 'cny',
    icon: '🐣',
  },
  {
    id: 'gstg-ref',
    name: 'Staging Ref',
    role: 'gstg-ref',
    stage: 'main',
    icon: '🚧',
  },
];

local annotations = [
  annotation.datasource(
    'Production deploys',
    '-- Grafana --',
    enable=true,
    iconColor='#19730E',
    tags=['deploy', 'gprd'],
  ),
  annotation.datasource(
    'Canary deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#E08400',
    tags=['deploy', 'gprd-cny'],
  ),
  annotation.datasource(
    'Staging deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#5794F2',
    tags=['deploy', 'gstg'],
  ),
  annotation.datasource(
    'Staging Canary deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#8F3BB8',
    tags=['deploy', 'gstg-cny'],
  ),
  annotation.datasource(
    'Staging Ref deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#EB0010',
    tags=['deploy', 'gstg-ref'],
  ),
];

local railsVersion(environment) =
  prometheus.target(
    |||
      label_replace(
        topk(1, count(
          gitlab_version_info{environment="%(env)s", stage="%(stage)s", component="gitlab-rails"}
        ) by (version)),
        "version", "$1",
        "version", "^([A-Fa-f0-9]{11}).*$"
      )
    ||| % { env: environment.role, stage: environment.stage },
    instant=true,
    format='table',
    legendFormat='{{version}}',
  );

local packageVersion(environment) =
  prometheus.target(
    |||
      topk(1, count(
        omnibus_build_info{environment="%(env)s", stage="%(stage)s"}
      ) by (version))
    ||| % { env: environment.role, stage: environment.stage },
    instant=true,
    format='table',
    legendFormat='{{version}}',
  );

local environmentPressurePanel(environment) =
  graphPanel.new(
    '%s Auto-deploy pressure' % [environment.icon],
    aliasColors={ Commits: 'semi-dark-purple' },
    decimals=0,
    labelY1='Commits',
    legend_show=false,
    min=0,
  )
  .addTarget(
    prometheus.target(
      'delivery_auto_deploy_pressure{job="delivery-metrics", role="%(role)s"}' % { role: environment.id },
      legendFormat='Commits',
    )
  );

local environmentIssuesPanel(environment) =
  graphPanel.new(
    '%s New Sentry issues' % [environment.icon],
    aliasColors={ Issues: 'dark-orange' },
    decimals=0,
    labelY1='Issues',
    legend_show=false,
    min=0,
  )
  .addTarget(
    prometheus.target(
      'delivery_sentry_issues{job="sentry-issues", role="%(role)s"}' % { role: environment.id },
      legendFormat='Issues',
    )
  );

// Stat panel used by top-level Auto-deploy Pressure and New Sentry issues
local
  deliveryStatPanel(
    title,
    description='',
    query='',
    legendFormat='',
    thresholdsMode='absolute',
    thresholds={},
    links=[]
  ) =
    statPanel.new(
      title,
      description=description,
      allValues=false,
      decimals=0,
      min=0,
      colorMode='value',
      graphMode='area',
      justifyMode='auto',
      orientation='horizontal',
      reducerFunction='lastNotNull',
      thresholdsMode=thresholdsMode,
    )
    .addLinks(links)
    .addThresholds(thresholds)
    .addTarget(
      promQuery.target(
        query,
        legendFormat=legendFormat
      )
    );

// Bar Gauge panel used by top-level Release pressure
local bargaugePanel(
  title,
  description='',
  query='',
  legendFormat='',
  thresholds={},
  links=[],
  fieldLinks=[],
  orientation='horizontal',
      ) =
  {
    description: description,
    fieldConfig: {
      values: false,
      defaults: {
        min: 0,
        max: 25,
        thresholds: thresholds,
        links: fieldLinks,
      },
    },
    links: links,
    options: {
      displayMode: 'basic',
      orientation: orientation,
      showUnfilled: true,
    },
    pluginVersion: '7.0.3',
    targets: [promQuery.target(query, legendFormat=legendFormat, instant=true)],
    title: title,
    type: 'bargauge',
  };

basic.dashboard(
  'Release Management',
  tags=['release'],
  editable=true,
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
)
.addAnnotations(annotations)

// ----------------------------------------------------------------------------
// Summary
// ----------------------------------------------------------------------------

.addPanel(
  row.new(title='Summary'),
  gridPos={ x: 0, y: 0, w: 24, h: 12 },
)
.addPanels(
  layout.splitColumnGrid([
    // Column 1: rails versions
    [
      statPanel.new(
        '%s %s' % [environment.icon, environment.id],
        description='Rails revision on %s.' % [environment.name],
        reducerFunction='lastNotNull',
        fields='/^version$/',
        colorMode='none',
        graphMode='none',
        textMode='value',
      )
      .addTarget(railsVersion(environment))
      for environment in environments
    ],
    // Column 2: package versions
    [
      statPanel.new(
        '%s %s' % [environment.icon, environment.id],
        description='Package running on %s.' % [environment.name],
        reducerFunction='lastNotNull',
        fields='/^version$/',
        colorMode='none',
        graphMode='none',
        textMode='value',
      )
      .addTarget(packageVersion(environment))
      for environment in environments
    ],
    // Column 3: auto-deploy pressure
    [
      // Auto-deploy pressure
      deliveryStatPanel(
        'Auto-deploy pressure',
        description='The number of commits in `master` not yet deployed to each environment.',
        query='max(delivery_auto_deploy_pressure{job="delivery-metrics"}) by (role)',
        legendFormat='{{role}}',
        thresholds=[
          { color: 'green', value: null },
          { color: '#EAB839', value: 50 },
          { color: '#EF843C', value: 100 },
          { color: 'red', value: 150 },
        ],
        links=[
          {
            targetBlank: true,
            title: 'Latest commits',
            url: 'https://gitlab.com/gitlab-org/gitlab/commits/master',
          },
        ],
      ),
    ],
    // Column 4: new sentry issues
    [
      // New Sentry issues
      deliveryStatPanel(
        'New Sentry issues',
        description='The number of new Sentry issues for each environment.',
        query='max(delivery_sentry_issues{role!=""}) by (role)',
        legendFormat='{{role}}',
        thresholds=[
          { color: 'green', value: null },
          { color: '#EAB839', value: 50 },
          { color: '#EF843C', value: 100 },
          { color: 'red', value: 150 },
        ],
        links=[
          {
            targetBlank: true,
            title: 'Sentry releases',
            url: 'https://sentry.gitlab.net/gitlab/gitlabcom/releases/',
          },
        ],
      ),
    ],
    // Column 5: release pressure
    [
      bargaugePanel(
        'Release pressure',
        description='Number of `Pick into` merge requests for previous releases.',
        query=|||
          sum(delivery_release_pressure{state="merged"}) by (state, version)
        |||,
        legendFormat='{{version}} ({{state}})',
        fieldLinks=[
          {
            title: 'View merge requests',
            url: 'https://gitlab.com/groups/gitlab-org/-/merge_requests?scope=all&state=${__field.labels.state}&label_name[]=Pick+into+${__field.labels.version}',
            targetBlank: true,
          },
        ],
        thresholds={
          mode: 'absolute',
          steps: [
            { color: 'green', value: null },
            { color: '#EAB839', value: 5 },
            { color: '#EF843C', value: 10 },
            { color: 'red', value: 15 },
          ],
        },
      ),
    ],
    // Column 6: Post deploy migration pressure
    [
      deliveryStatPanel(
        'Pending migrations',
        description='The number of migrations pending execution in each environment.',
        query='sum(delivery_metrics_pending_migrations_total{env=~"gstg|gprd",stage="main"}) by (env)',
        legendFormat='{{env}}',
        thresholds=[
          { color: 'green', value: null },
          { color: '#EAB839', value: 3 },
          { color: '#EF843C', value: 4 },
          { color: 'red', value: 5 },
        ],
      ),
    ],
  ], cellHeights=[3 for x in environments], startRow=1)
)
.addPanels(
  std.flattenArrays(
    std.mapWithIndex(
      function(index, environment)
        local y = 1000 * (index + 1);
        [
          row.new(
            title='%s %s' % [environment.icon, environment.id]
          )
          { gridPos: { x: 0, y: y, w: 24, h: 12 } },
        ]
        +
        layout.grid(
          [
            environmentPressurePanel(environment),
            environmentIssuesPanel(environment),
          ],
          cols=2,
          startRow=y + 1
        ),
      environments
    )
  )
)
.trailer()
