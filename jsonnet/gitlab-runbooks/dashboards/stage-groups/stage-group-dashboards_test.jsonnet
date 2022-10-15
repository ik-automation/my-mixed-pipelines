local stageGroupDashboards = import './stage-group-dashboards.libsonnet';
local matcher = import 'jsonnetunit/matcher.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';
local test = import 'test.libsonnet';

local errorBudgetTitles = [
  'Error Budget (past 28 days)',
  'Availability',
  'Budget remaining',
  'Budget spent',
  'Info',
  'Budget spend attribution',
];

local allComponentTitles = [
  'Rails Request Rates',
  'API Request Rate',
  'WEB Request Rate',
  'Extra links',
  'Rails 95th Percentile Request Latency',
  'API 95th Percentile Request Latency',
  'WEB 95th Percentile Request Latency',
  'Rails Error Rates (accumulated by components)',
  'API Error Rate',
  'WEB Error Rate',
  'SQL Queries Per Action',
  'API SQL Queries per Action',
  'WEB SQL Queries per Action',
  'SQL Latency Per Action',
  'API SQL Latency per Action',
  'WEB SQL Latency per Action',
  'SQL Latency Per Query',
  'API SQL Latency per Query',
  'WEB SQL Latency per Query',
  'Caches per Action',
  'API Caches per Action',
  'WEB Caches per Action',
  'Sidekiq',
  'Sidekiq Completion Rate',
  'Sidekiq Error Rate',
  'Extra links',
  'Source',
];

local panelTitles(dashboard) =
  std.filter(function(title) title != '', [panel.title for panel in dashboard.panels]);

test.suite({
  testTemplates: {
    actual: [template.name for template in stageGroupDashboards.dashboard('geo').stageGroupDashboardTrailer().templating.list],
    expect: [
      'PROMETHEUS_DS',
      'environment',
      'stage',
      'controller',
      'action',
    ],
  },

  testTitle: {
    actual: stageGroupDashboards.dashboard('geo').stageGroupDashboardTrailer().title,
    expect: 'Geo: Group dashboard',
  },

  testTags: {
    actual: stageGroupDashboards.dashboard('geo').stageGroupDashboardTrailer().tags,
    expect: ['feature_category', 'stage_group:Geo'],
  },

  testDefaultComponents: {
    actual: panelTitles(stageGroupDashboards.dashboard('geo').stageGroupDashboardTrailer()),
    expect: errorBudgetTitles + allComponentTitles,
  },

  testLinks: {
    actual: std.map(function(links) links.title, stageGroupDashboards.dashboard('geo').links),
    expect: ['Group Dashboards', 'API Detail', 'Web Detail', 'Git Detail'],
  },

  testDisplayEmptyGuidance: {
    introPanels: [
      'Introduction',
      'Introduction',
    ],
    actual: panelTitles(stageGroupDashboards.dashboard('geo', displayEmptyGuidance=true).stageGroupDashboardTrailer()),
    expect: self.introPanels + errorBudgetTitles + allComponentTitles,
  },

  testWeb: {
    webTitles: [
      'Rails Request Rates',
      'WEB Request Rate',
      'Extra links',
      'Rails 95th Percentile Request Latency',
      'WEB 95th Percentile Request Latency',
      'Rails Error Rates (accumulated by components)',
      'WEB Error Rate',
      'SQL Queries Per Action',
      'WEB SQL Queries per Action',
      'SQL Latency Per Action',
      'WEB SQL Latency per Action',
      'SQL Latency Per Query',
      'WEB SQL Latency per Query',
      'Caches per Action',
      'WEB Caches per Action',
      'Source',
    ],
    actual: panelTitles(stageGroupDashboards.dashboard('geo', components=['web']).stageGroupDashboardTrailer()),
    expect: errorBudgetTitles + self.webTitles,
  },

  testApiWeb: {
    apiWebTitles: [
      'Rails Request Rates',
      'API Request Rate',
      'WEB Request Rate',
      'Extra links',
      'Rails 95th Percentile Request Latency',
      'API 95th Percentile Request Latency',
      'WEB 95th Percentile Request Latency',
      'Rails Error Rates (accumulated by components)',
      'API Error Rate',
      'WEB Error Rate',
      'SQL Queries Per Action',
      'API SQL Queries per Action',
      'WEB SQL Queries per Action',
      'SQL Latency Per Action',
      'API SQL Latency per Action',
      'WEB SQL Latency per Action',
      'SQL Latency Per Query',
      'API SQL Latency per Query',
      'WEB SQL Latency per Query',
      'Caches per Action',
      'API Caches per Action',
      'WEB Caches per Action',
      'Source',
    ],
    actual: panelTitles(stageGroupDashboards.dashboard('geo', components=['api', 'web']).stageGroupDashboardTrailer()),
    expect: errorBudgetTitles + self.apiWebTitles,
  },

  testGit: {
    gitTitles: [
      'Rails Request Rates',
      'GIT Request Rate',
      'Extra links',
      'Rails 95th Percentile Request Latency',
      'GIT 95th Percentile Request Latency',
      'Rails Error Rates (accumulated by components)',
      'GIT Error Rate',
      'SQL Queries Per Action',
      'GIT SQL Queries per Action',
      'SQL Latency Per Action',
      'GIT SQL Latency per Action',
      'SQL Latency Per Query',
      'GIT SQL Latency per Query',
      'Caches per Action',
      'GIT Caches per Action',
      'Source',
    ],
    actual: panelTitles(stageGroupDashboards.dashboard('geo', components=['git']).stageGroupDashboardTrailer()),
    expect: errorBudgetTitles + self.gitTitles,
  },

  testSidekiqPanels: {
    sidekiqTitles: [
      'Sidekiq',
      'Sidekiq Completion Rate',
      'Sidekiq Error Rate',
      'Extra links',
      'Source',
    ],
    actual: panelTitles(stageGroupDashboards.dashboard('geo', components=['sidekiq']).stageGroupDashboardTrailer()),
    expect: errorBudgetTitles + self.sidekiqTitles,
  },

  testSidekiqOnlyTemplates: {
    actual: std.prune([template.name for template in stageGroupDashboards.dashboard('geo', components=['sidekiq']).stageGroupDashboardTrailer().templating.list]),
    expect: [
      'PROMETHEUS_DS',
      'environment',
      'stage',
    ],
  },

  testErrorBudgetDetailDashboard: {
    actual: panelTitles(stageGroupDashboards.errorBudgetDetailDashboard({
      key: 'project_management',
      name: 'Project Management',
      stage: 'plan',
      feature_categories: ['team_planning', 'planning_analytics'],
    })),
    expect: [
      'Error Budget (From ${__from:date:YYYY-MM-DD HHːmm} to ${__to:date:YYYY-MM-DD HHːmm})',
      'Availability',
      'Budget remaining',
      'Budget spent',
      'Info',
      'Budget spend attribution',
      '🌡️ Aggregated Service Level Indicators (𝙎𝙇𝙄𝙨)',
      'Overall Apdex',
      'Overall Error Ratio',
      'Overall RPS - Requests per Second',
      '🔬 Service Level Indicators',
      '🔬 SLI Detail: graphql_queries',
      '🔬 SLI Detail: puma',
      '🔬 SLI Detail: rails_requests',
      '🔬 SLI Detail: sidekiq_execution',
    ],
  },

  testErrorBudgetDetailLinks: {
    actual: std.map(
      function(links) links.title,
      stageGroupDashboards.dashboard({
        key: 'project_management',
        name: 'Project Management',
        stage: 'plan',
        feature_categories: ['team_planning', 'planning_analytics'],
      }).links
    ),
    expect: ['Group Dashboards', 'API Detail', 'Web Detail', 'Git Detail'],
  },


  testDashboardUidTooLong: {
    actual: stageGroupDashboards.dashboardUid('authentication_and_authorization'),
    expect: 'authentication_and_authoriz',
  },

  testDashboardUidTooLongWithPrefix: {
    actual: stageGroupDashboards.dashboardUid('detail-authentication_and_authorization'),
    expect: 'detail-authentication_and_a',
  },

  testDashboardUidNoChange: {
    actual: stageGroupDashboards.dashboardUid('access'),
    expect: 'access',
  },

  testDashboardUidAllUnique: {
    actual: std.map(function(s) s.key, stages.stageGroupsWithoutNotOwned),
    expectUniqueMappings: stageGroupDashboards.dashboardUid,
  },
})
