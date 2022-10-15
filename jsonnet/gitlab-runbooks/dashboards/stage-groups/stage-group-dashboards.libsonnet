local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local stages = (import 'service-catalog/stages.libsonnet');
local template = grafana.template;
local prebuiltTemplates = import 'grafana/templates.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local errorBudget = import 'stage-groups/error_budget.libsonnet';
local errorBudgetUtils = import 'stage-groups/error-budget/utils.libsonnet';
local sidekiqHelpers = import 'services/lib/sidekiq-helpers.libsonnet';
local thresholds = import 'gitlab-dashboards/thresholds.libsonnet';
local metricsCatalogDashboards = import 'gitlab-dashboards/metrics_catalog_dashboards.libsonnet';
local gitlabMetricsConfig = import 'gitlab-metrics-config.libsonnet';
local keyMetrics = import 'gitlab-dashboards/key_metrics.libsonnet';
local objects = import 'utils/objects.libsonnet';

local aggregationSets = gitlabMetricsConfig.aggregationSets;

local dashboardUid(identifier) =
  local dirname = 'stage-groups';
  // All dashboards are prefixed with their dirname joined by a `-`
  local maxLength = 40 - std.length(dirname) - 1;
  std.substr(identifier, 0, maxLength);

local actionLegend(type) =
  if type == 'api' then '{{action}}' else '{{controller}}#{{action}}';

local controllerFilter(featureCategoriesSelector) =
  template.new(
    'controller',
    '$PROMETHEUS_DS',
    "label_values(controller_action:gitlab_transaction_duration_seconds_count:rate1m{environment='$environment', feature_category=~'(%s)'}, controller)" % featureCategoriesSelector,
    current=null,
    refresh='load',
    sort=1,
    includeAll=true,
    allValues='.*',
    multi=true,
  );

local actionFilter(featureCategoriesSelector) =
  template.new(
    'action',
    '$PROMETHEUS_DS',
    "label_values(controller_action:gitlab_transaction_duration_seconds_count:rate1m{environment='$environment', controller=~'$controller', feature_category=~'(%s)'}, action)" % featureCategoriesSelector,
    current=null,
    refresh='load',
    sort=1,
    multi=true,
    includeAll=true,
    allValues='.*'
  );

local errorBudgetPanels(group, budget) =
  [
    [
      budget.panels.availabilityStatPanel(group.key),
      budget.panels.errorBudgetStatusPanel(group.key),
      budget.panels.availabilityTargetStatPanel(group.key),
    ],
    [
      budget.panels.timeRemainingStatPanel(group.key),
      budget.panels.errorBudgetStatusPanel(group.key),
      budget.panels.timeRemainingTargetStatPanel(group.key),
    ],
    [
      budget.panels.timeSpentStatPanel(group.key),
      budget.panels.errorBudgetStatusPanel(group.key),
      budget.panels.timeSpentTargetStatPanel(group.key),
    ],
    [
      budget.panels.explanationPanel(group.name),
    ],
  ];

local errorBudgetAttribution(group, budget, featureCategories) =
  [
    budget.panels.violationRatePanel(group.key),
    budget.panels.violationRateExplanation,
    budget.panels.logLinks(featureCategories),
  ];

local railsRequestRate(type, featureCategories, featureCategoriesSelector) =
  basic.timeseries(
    title='%(type)s Request Rate' % { type: std.asciiUpper(type) },
    yAxisLabel='Requests per Second',
    legendFormat=actionLegend(type),
    decimals=2,
    query=|||
      sum by (controller, action) (
        rate(gitlab_transaction_duration_seconds_count{
          environment='$environment',
          stage='$stage',
          feature_category=~'(%(featureCategories)s)',
          type='%(type)s',
          controller=~'$controller',
          action=~'$action'
        }[$__interval])
      )
    ||| % {
      type: type,
      featureCategories: featureCategoriesSelector,
    }
  );

local railsErrorRate(type, featureCategories, featureCategoriesSelector) =
  basic.timeseries(
    title='%(type)s Error Rate' % { type: std.asciiUpper(type) },
    decimals=2,
    legendFormat='%s error rate' % type,
    yAxisLabel='Requests per Second',
    query=|||
      sum by (component) (
        gitlab:component:feature_category:execution:error:rate_5m{
          environment='$environment',
          stage='$stage',
          feature_category=~'(%(featureCategories)s)',
          type='%(type)s'
        }
      )
    ||| % {
      type: type,
      featureCategories: featureCategoriesSelector,
    }
  );

local railsP95RequestLatency(type, featureCategories, featureCategoriesSelector) =
  basic.timeseries(
    title='%(type)s 95th Percentile Request Latency' % { type: std.asciiUpper(type) },
    decimals=2,
    format='s',
    legendFormat=actionLegend(type),
    query=|||
      avg(
        avg_over_time(
          controller_action:gitlab_transaction_duration_seconds:p95{
            environment="$environment",
            stage='$stage',
            action=~"$action",
            controller=~"$controller",
            feature_category=~'(%(featureCategories)s)',
            type='%(type)s'
          }[$__interval]
        )
      ) by (controller, action)
    ||| % {
      type: type,
      featureCategories: featureCategoriesSelector,
    }
  );

local sqlQueriesPerAction(type, featureCategories, featureCategoriesSelector) =
  basic.timeseries(
    title='%(type)s SQL Queries per Action' % { type: std.asciiUpper(type) },
    decimals=2,
    yAxisLabel='Queries',
    legendFormat=actionLegend(type),
    description=|||
      Average amount of SQL queries performed by a controller action.
    |||,
    query=|||
      sum by (controller, action) (
        controller_action:gitlab_sql_duration_seconds_count:rate1m{
          environment="$environment",
          stage='$stage',
          action=~"$action",
          controller=~"$controller",
          feature_category=~'(%(featureCategories)s)',
          type='%(type)s'
        }
      )
      /
      sum by (controller, action) (
        controller_action:gitlab_transaction_duration_seconds_count:rate1m{
          environment="$environment",
          stage='$stage',
          action=~"$action",
          controller=~"$controller",
          feature_category=~'(%(featureCategories)s)',
          type='%(type)s'
        }
      )
    ||| % {
      type: type,
      featureCategories: featureCategoriesSelector,
    }
  );

local sqlLatenciesPerAction(type, featureCategories, featureCategoriesSelector) =
  basic.timeseries(
    title='%(type)s SQL Latency per Action' % { type: std.asciiUpper(type) },
    decimals=2,
    format='s',
    legendFormat=actionLegend(type),
    description=|||
      Average sum of all SQL query latency accumulated by a controller action.
    |||,
    query=|||
      avg_over_time(
        controller_action:gitlab_sql_duration_seconds_sum:rate1m{
          environment="$environment",
          stage='$stage',
          action=~"$action",
          controller=~"$controller",
          feature_category=~'(%(featureCategories)s)',
          type='%(type)s'
        }[$__interval]
      )
      /
      avg_over_time(
        controller_action:gitlab_transaction_duration_seconds_count:rate1m{
          environment="$environment",
          stage='$stage',
          action=~"$action",
          controller=~"$controller",
          feature_category=~'(%(featureCategories)s)',
          type='%(type)s'
        }[$__interval]
      )
    ||| % {
      type: type,
      featureCategories: featureCategoriesSelector,
    }
  );

local sqlLatenciesPerQuery(type, featureCategories, featureCategoriesSelector) =
  basic.timeseries(
    title='%(type)s SQL Latency per Query' % { type: std.asciiUpper(type) },
    decimals=2,
    legendFormat=actionLegend(type),
    format='s',
    description=|||
      Average latency of individual SQL queries
    |||,
    query=|||
      sum by (controller, action) (
        rate(
          gitlab_sql_duration_seconds_sum{
            environment="$environment",
            stage='$stage',
            action=~"$action",
            controller=~"$controller",
            feature_category=~'(%(featureCategories)s)',
            type='%(type)s'
          }[$__interval]
        )
      )
      /
      sum by (controller, action) (
        rate(
          gitlab_sql_duration_seconds_count{
            environment="$environment",
            stage='$stage',
            action=~"$action",
            controller=~"$controller",
            feature_category=~'(%(featureCategories)s)',
            type='%(type)s'
          }[$__interval]
        )
      )
    ||| % {
      type: type,
      featureCategories: featureCategoriesSelector,
    }
  );

local cachesPerAction(type, featureCategories, featureCategoriesSelector) =
  basic.timeseries(
    title='%(type)s Caches per Action' % { type: std.asciiUpper(type) },
    decimals=2,
    legendFormat='{{operation}} - %s' % actionLegend(type),
    yAxisLabel='Operations',
    description=|||
      Average total number of caching operations (Read & Write) per action.
    |||,
    query=|||
      sum by (controller, action, operation) (
        rate(
          gitlab_cache_operations_total{
            environment="$environment",
            stage='$stage',
            action=~"$action",
            controller=~"$controller",
            feature_category=~'(%(featureCategories)s)',
            type='%(type)s'
          }[$__interval]
        )
      )
    ||| % {
      type: type,
      featureCategories: featureCategoriesSelector,
    }
  );

local sidekiqJobRate(counter, title, description, featureCategoriesSelector) =
  basic.timeseries(
    title=title,
    description=description,
    decimals=2,
    yAxisLabel='Jobs per Second',
    legendFormat='{{worker]}}',
    query=|||
      sum by (worker) (
        rate(%(counter)s{
          environment="$environment",
          stage='$stage',
          feature_category=~'(%(featureCategories)s)'
        }[$__interval])
      )
    ||| % {
      counter: counter,
      featureCategories: featureCategoriesSelector,
    }
  );

local sidekiqJobDurationP95(featureCategories, urgency, threshold) =
  basic.timeseries(
    title='%s urgency jobs' % urgency,
    description='%(urgency)s urgency jobs (%(threshold)i seconds max duration)' % {
      urgency: urgency,
      threshold: threshold,
    },
    decimals=2,
    yAxisLabel='Job Duration seconds',
    legendFormat='{{ worker }}',
    thresholds=[thresholds.errorLevel('gt', threshold)],
    query=|||
      histogram_quantile(0.95,
        sum by (worker, le) (
          rate(
            sidekiq_jobs_completion_seconds_bucket{
              environment="$environment",
              stage='$stage',
              feature_category=~'(%(featureCategories)s)',
              urgency='%(urgency)s'
            }[$__interval]
          )
        )
      )
    ||| % {
      featureCategories: featureCategories,
      urgency: urgency,
    }
  );

local sidekiqJobDurationByUrgency(urgencies, featureCategoriesSelector) =
  // mapping an urgency to the slo key in `services/lib/sidekiq-helpers.libsonnet`
  local urgencySLOMapping = {
    high: 'urgent',
    low: 'lowUrgency',
    throttled: 'throttled',
  };
  local unknownUrgencies = std.setDiff(urgencies, std.objectFields(urgencySLOMapping));
  assert std.length(unknownUrgencies) == 0 :
         'Unknown urgency %s' % unknownUrgencies;
  local slos = sidekiqHelpers.slos;

  layout.rowGrid(
    'Sidekiq job duration',
    [
      sidekiqJobDurationP95(featureCategoriesSelector, urgency, slos[urgencySLOMapping[urgency]].executionDurationSeconds)
      for urgency in urgencies
    ],
    // Just after the sidekiq panels
    startRow=950,
  );

local requestComponents = std.set(['web', 'api', 'git']);
local backgroundComponents = std.set(['sidekiq']);
local supportedComponents = std.setUnion(requestComponents, backgroundComponents);
local defaultComponents = std.set(['web', 'api', 'sidekiq']);
local groupTag(group) = 'stage_group:%s' % group.name;

local commonHeader(
  group,
  extraTags=[],
  featureCategories,
  featureCategoriesSelector,
  displayControllerFilter,
  enabledRequestComponents,
  displayEmptyGuidance,
  displayBudget,
  title,
  budget,
  time_from='now-6h/m',
  time_to='now/m'
      ) =
  basic
  .dashboard(
    title,
    tags=[
      'feature_category',
      groupTag(group),
    ] + extraTags,
    time_from=time_from,
    time_to=time_to,
  )
  .addTemplate(prebuiltTemplates.stage)
  .addTemplates(
    if displayControllerFilter && std.length(enabledRequestComponents) != 0 then
      [controllerFilter(featureCategoriesSelector), actionFilter(featureCategoriesSelector)]
    else
      []
  )
  .addPanels(
    if displayEmptyGuidance then
      layout.rowGrid(
        'Introduction',
        [
          grafana.text.new(
            title='Introduction',
            mode='markdown',
            content=|||
              You may see there are some empty panels in this dashboard. The metrics in each dashboard are filtered and accumulated based on the GitLab [product categories](https://about.gitlab.com/handbook/product/categories/) and [feature categories](https://docs.gitlab.com/ee/development/feature_categorization/index.html).
              - If your stage group hasn't declared a feature category, please follow the feature category guideline.
              - If your stage group doesn't use a particular component, you can always [customize this dashboard](https://docs.gitlab.com/ee/development/stage_group_dashboards.html#how-to-customize-the-dashboard) to exclude irrelevant panels.

              For more information, please visit [Dashboards for stage groups](https://docs.gitlab.com/ee/development/stage_group_dashboards.html) or watch [Guide to getting started with dashboards for stage groups](https://youtu.be/xB3gHlKCZpQ).

              The dashboards for stage groups are at a very early stage. All contributions are welcome. If you have any questions or suggestions, please submit an issue in the [Scalability Team issues tracker](https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/new).
            |||,
          ),
        ],
        startRow=0
      )
    else
      []
  )
  .addPanels(
    if displayBudget then
      // Errorbudgets are always viewed over a 28d rolling average, regardles of the
      // selected range see the configuration in `libsonnet/stage-groups/error_budget.libsonnet`
      local title =
        if budget.isDynamicRange then
          'Error Budget (From ${__from:date:YYYY-MM-DD HHːmm} to ${__to:date:YYYY-MM-DD HHːmm})'
        else
          'Error Budget (past 28 days)';
      layout.splitColumnGrid(errorBudgetPanels(group, budget), startRow=100, cellHeights=[4, 1.5, 1.5], title=title) +
      layout.rowGrid('Budget spend attribution', errorBudgetAttribution(group, budget, featureCategories), startRow=150, collapse=true)
    else
      []
  ) {
    links+: [
      platformLinks.dynamicLinks('Group Dashboards', groupTag(group), asDropdown=false),
    ],
  }
;

local getEnabledRequestComponents(components) =
  assert std.type(components) == 'array' : 'Invalid components argument type';

  local setComponents = std.set(components);
  local invalidComponents = std.setDiff(setComponents, supportedComponents);
  assert std.length(invalidComponents) == 0 :
         'Invalid components: ' + std.join(', ', invalidComponents);

  std.setInter(requestComponents, setComponents);

local dashboard(groupKey, components=defaultComponents, displayEmptyGuidance=false, displayBudget=true) =
  local group = stages.stageGroup(groupKey);
  local featureCategories = stages.categoriesForStageGroup(groupKey);
  local featureCategoriesSelector = std.join('|', featureCategories);
  local enabledRequestComponents = getEnabledRequestComponents(components);

  local dashboard =
    commonHeader(
      group=group,
      featureCategories=featureCategories,
      featureCategoriesSelector=featureCategoriesSelector,
      displayControllerFilter=true,
      enabledRequestComponents=enabledRequestComponents,
      displayEmptyGuidance=displayEmptyGuidance,
      displayBudget=displayBudget,
      title='%s: Group dashboard' % [group.name],
      budget=errorBudget(),
    )
    .addPanels(
      if std.length(enabledRequestComponents) != 0 then
        layout.rowGrid(
          'Rails Request Rates',
          [
            railsRequestRate(component, featureCategories, featureCategoriesSelector)
            for component in enabledRequestComponents
          ] +
          [
            grafana.text.new(
              title='Extra links',
              mode='markdown',
              content=toolingLinks.generateMarkdown([
                toolingLinks.kibana(
                  title='Kibana Rails',
                  index='rails',
                  matches={
                    'json.meta.feature_category': featureCategories,
                  },
                ),
                toolingLinks.sentry(slug='gitlab/gitlabcom', featureCategories=featureCategories, variables=['environment', 'stage']),
              ], { prometheusSelectorHash: {} })
            ),
          ],
          startRow=201
        )
        +
        layout.rowGrid(
          'Rails 95th Percentile Request Latency',
          [
            railsP95RequestLatency(component, featureCategories, featureCategoriesSelector)
            for component in enabledRequestComponents
          ],
          startRow=301
        )
        +
        layout.rowGrid(
          'Rails Error Rates (accumulated by components)',
          [
            railsErrorRate(component, featureCategories, featureCategoriesSelector)
            for component in enabledRequestComponents
          ],
          startRow=401
        )
        +
        layout.rowGrid(
          'SQL Queries Per Action',
          [
            sqlQueriesPerAction(component, featureCategories, featureCategoriesSelector)
            for component in enabledRequestComponents
          ],
          startRow=501
        )
        +
        layout.rowGrid(
          'SQL Latency Per Action',
          [
            sqlLatenciesPerAction(component, featureCategories, featureCategoriesSelector)
            for component in enabledRequestComponents
          ],
          startRow=601
        )
        +
        layout.rowGrid(
          'SQL Latency Per Query',
          [
            sqlLatenciesPerQuery(component, featureCategories, featureCategoriesSelector)
            for component in enabledRequestComponents
          ],
          startRow=701
        )
        +
        layout.rowGrid(
          'Caches per Action',
          [
            cachesPerAction(component, featureCategories, featureCategoriesSelector)
            for component in enabledRequestComponents
          ],
          startRow=801
        )
      else
        []
    )
    .addPanels(
      if std.member(components, 'sidekiq') then
        layout.rowGrid(
          'Sidekiq',
          [
            sidekiqJobRate(
              'sidekiq_jobs_completion_seconds_count',
              'Sidekiq Completion Rate',
              'The rate (Jobs per Second) at which jobs are completed after dequeue',
              featureCategoriesSelector
            ),
            sidekiqJobRate(
              'sidekiq_jobs_failed_total',
              'Sidekiq Error Rate',
              'The rate (Jobs per Second) at which jobs fail after dequeue',
              featureCategoriesSelector
            ),
            grafana.text.new(
              title='Extra links',
              mode='markdown',
              content=toolingLinks.generateMarkdown([
                toolingLinks.kibana(
                  title='Kibana Sidekiq',
                  index='sidekiq',
                  matches={
                    'json.meta.feature_category': featureCategories,
                  },
                ),
                toolingLinks.sentry(slug='gitlab/gitlabcom', type='sidekiq', featureCategories=featureCategories, variables=['environment', 'stage']),
              ], { prometheusSelectorHash: {} })
            ),
          ],
          startRow=901
        )
      else
        []
    );

  dashboard {
    stageGroupDashboardTrailer()::
      // Add any additional trailing panels here
      self.trailer(),
    links+:
      [
        platformLinks.dynamicLinks('API Detail', 'type:api'),
        platformLinks.dynamicLinks('Web Detail', 'type:web'),
        platformLinks.dynamicLinks('Git Detail', 'type:git'),
      ],
    addSidekiqJobDurationByUrgency(urgencies=['high', 'low'])::
      self.addPanels(sidekiqJobDurationByUrgency(urgencies, featureCategoriesSelector)),
  };

local errorBudgetDetailDashboard(stageGroup) =
  // Missing `feature_category` labels are also accepted for viewing details with a static feature category
  local featureCategoriesSelector = std.join('|', stageGroup.feature_categories + ['']);
  local serviceTypes = std.map(function(service) service.type, gitlabMetricsConfig.monitoredServices);

  local sliFilter = function(sli)
    sli.hasFeatureCategoryFromSourceMetrics() || (
      sli.hasStaticFeatureCategory() && std.member(stageGroup.feature_categories, sli.featureCategory)
    );

  local budget = errorBudget(errorBudgetUtils.dynamicRange);

  local dashboard =
    commonHeader(
      group=stageGroup,
      extraTags=[],
      featureCategories=stageGroup.feature_categories,
      featureCategoriesSelector=featureCategoriesSelector,
      displayControllerFilter=false,
      enabledRequestComponents=requestComponents,
      displayEmptyGuidance=false,
      displayBudget=true,
      title='%s: group error budget detail' % [stageGroup.name],
      budget=budget,
      time_from='now-28d/m',
    )
    .addPanels(
      keyMetrics.headlineMetricsRow(
        startRow=200,
        serviceType=null,
        selectorHash={
          environment: '$environment',
          stage: '$stage',
          stage_group: stageGroup.key,
        },
        staticTitlePrefix='Overall',
        legendFormatPrefix=stageGroup.name,
        aggregationSet=aggregationSets.stageGroupSLIs,
        showApdex=true,
        showErrorRatio=true,
        showOpsRate=true,
        showSaturationCell=false,
        includeLastWeek=false,
        compact=true,
        rowHeight=8,
        fixedThreshold=budget.slaTarget
      )
    )
    .addPanels(
      metricsCatalogDashboards.sliMatrixAcrossServices(
        title='🔬 Service Level Indicators',
        serviceTypes=serviceTypes,
        aggregationSet=aggregationSets.serviceComponentStageGroupSLIs,
        startRow=300,
        expectMultipleSeries=true,
        legendFormatPrefix='{{ type }}',
        selectorHash={
          environment: '$environment',
          stage: '$stage',
          stage_group: stageGroup.key,
        },
        sliFilter=sliFilter,
      )
    )
    .addPanels(
      metricsCatalogDashboards.autoDetailRowsAcrossServices(
        serviceTypes=serviceTypes,
        selectorHash={
          environment: '$environment',
          stage: '$stage',
          feature_category: { re: featureCategoriesSelector },
        },
        startRow=1200,
        sliFilter=sliFilter,
      )
    );

  dashboard {
    stageGroupDashboardTrailer()::
      // Add any additional trailing panels here
      self.trailer(),
    links+:
      [
        platformLinks.dynamicLinks('API Detail', 'type:api'),
        platformLinks.dynamicLinks('Web Detail', 'type:web'),
        platformLinks.dynamicLinks('Git Detail', 'type:git'),
      ],
  };

{
  // dashboard generates a basic stage group dashboard for a stage group
  // The group should match a group a `stage` from `./services/stage-group-mapping.jsonnet`
  dashboard: dashboard,
  errorBudgetDetailDashboard: errorBudgetDetailDashboard,
  supportedComponents: supportedComponents,
  dashboardUid: dashboardUid,
}
