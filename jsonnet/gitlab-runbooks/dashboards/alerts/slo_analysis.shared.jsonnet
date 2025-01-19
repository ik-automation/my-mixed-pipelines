local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local template = grafana.template;
local multiburnFactors = import 'mwmbr/multiburn_factors.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local statusDescription = import 'key-metric-panels/status_description.libsonnet';
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;

local apdexSLOMetric = 'slo:min:events:gitlab_service_apdex:ratio';
local errorSLOMetric = 'slo:max:events:gitlab_service_errors:ratio';

local errorBurnRatePair(aggregationSet, shortDuration, longDuration, selectorHash) =
  local formatConfig = {
    shortMetric: aggregationSet.getErrorRatioMetricForBurnRate(shortDuration, required=true),
    shortDuration: shortDuration,
    longMetric: aggregationSet.getErrorRatioMetricForBurnRate(longDuration, required=true),
    longDuration: longDuration,
    longBurnFactor: multiburnFactors.errorBudgetFactorFor(longDuration),
    selector: selectors.serializeHash(selectorHash + aggregationSet.selector),
    thresholdSLOMetricName: errorSLOMetric,
  };

  local longQuery =
    |||
      %(longMetric)s{%(selector)s}
    ||| % formatConfig;

  local shortQuery =
    |||
      %(shortMetric)s{%(selector)s}
    ||| % formatConfig;

  [
    {
      legendFormat: '%(longDuration)s error burn rate' % formatConfig,
      query: longQuery,
    },
    {
      legendFormat: '%(shortDuration)s error burn rate' % formatConfig,
      query: shortQuery,
    },
    {
      legendFormat: '%(longDuration)s error burn threshold' % formatConfig,
      query: '(%(longBurnFactor)g * avg(%(thresholdSLOMetricName)s{monitor="global", type="$type"})) unless (vector($proposed_slo) > 0)' % formatConfig,
    },
    {
      legendFormat: 'Proposed SLO @ %(longDuration)s burn' % formatConfig,
      query: '%(longBurnFactor)g * (1 - $proposed_slo)' % formatConfig,
    },
  ];

local apdexBurnRatePair(aggregationSet, shortDuration, longDuration, selectorHash) =
  local formatConfig = {
    shortMetric: aggregationSet.getApdexRatioMetricForBurnRate(shortDuration, required=true),
    shortDuration: shortDuration,
    longMetric: aggregationSet.getApdexRatioMetricForBurnRate(longDuration, required=true),
    longDuration: longDuration,
    longBurnFactor: multiburnFactors.errorBudgetFactorFor(longDuration),
    selector: selectors.serializeHash(selectorHash + aggregationSet.selector),
    thresholdSLOMetricName: apdexSLOMetric,
  };

  local longQuery =
    |||
      %(longMetric)s{%(selector)s}
    ||| % formatConfig;

  local shortQuery =
    |||
      %(shortMetric)s{%(selector)s}
    ||| % formatConfig;

  [
    {
      legendFormat: '%(longDuration)s apdex burn rate' % formatConfig,
      query: longQuery,
    },
    {
      legendFormat: '%(shortDuration)s apdex burn rate' % formatConfig,
      query: shortQuery,
    },
    {
      legendFormat: '%(longDuration)s apdex burn threshold' % formatConfig,
      query: '(1 - (%(longBurnFactor)g * (1 - avg(%(thresholdSLOMetricName)s{monitor="global", type="$type"})))) unless (vector($proposed_slo) > 0) ' % formatConfig,
    },
    {
      legendFormat: 'Proposed SLO @ %(longDuration)s burn' % formatConfig,
      query: '1 - (%(longBurnFactor)g * (1 - $proposed_slo))' % formatConfig,
    },
  ];

local burnRatePanel(
  title,
  combinations,
  stableId,
      ) =
  local basePanel = basic.percentageTimeseries(
    title=title,
    decimals=4,
    description='apdex burn rates: higher is better',
    query=combinations[0].query,
    legendFormat=combinations[0].legendFormat,
    stableId=stableId,
  );

  std.foldl(
    function(memo, combo)
      memo.addTarget(promQuery.target(combo.query, legendFormat=combo.legendFormat)),
    combinations[1:],
    basePanel
  )
  .addSeriesOverride({
    alias: '6h apdex burn rate',
    color: '#5794F2',
    linewidth: 4,
    zindex: 0,
    fillBelowTo: '30m apdex burn rate',
  })
  .addSeriesOverride({
    alias: '1h apdex burn rate',
    color: '#73BF69',
    linewidth: 4,
    zindex: 1,
    fillBelowTo: '5m apdex burn rate',
  })
  .addSeriesOverride({
    alias: '30m apdex burn rate',
    color: '#5794F2',
    linewidth: 2,
    zindex: 2,
  })
  .addSeriesOverride({
    alias: '5m apdex burn rate',
    color: '#73BF69',
    linewidth: 2,
    zindex: 3,
  })
  .addSeriesOverride({
    alias: '6h apdex burn threshold',
    color: '#5794F2',
    dashLength: 2,
    dashes: true,
    lines: true,
    linewidth: 2,
    spaceLength: 4,
    zindex: -1,
  })
  .addSeriesOverride({
    alias: '1h apdex burn threshold',
    color: '#73BF69',
    dashLength: 2,
    dashes: true,
    lines: true,
    linewidth: 2,
    spaceLength: 4,
    zindex: -2,
  });

local burnRatePanelWithHelp(
  title,
  combinations,
  content,
  stableId=null,
      ) =
  [
    burnRatePanel(title, combinations, stableId),
    grafana.text.new(
      title='Help',
      mode='markdown',
      content=content
    ),
  ];

local ignoredTemplateLabels = std.set(['env', 'tier']);

local generateTemplatesAndSelectorHash(sliType, aggregationSet, dashboard) =
  local metric = if sliType == 'error' then
    aggregationSet.getErrorRatioMetricForBurnRate('1h')
  else
    aggregationSet.getApdexRatioMetricForBurnRate('1h');

  std.foldl(
    function(memo, label)
      if std.member(ignoredTemplateLabels, label) then
        memo
      else
        local dashboard = memo.dashboard;
        local selectorHash = memo.selectorHash;

        local formatConfig = {
          metric: metric,
          label: label,
          selector: selectors.serializeHash(selectorHash),
        };

        local t = template.new(
          label,
          '$PROMETHEUS_DS',
          'label_values(%(metric)s{%(selector)s}, %(label)s)' % formatConfig,
          refresh='time',
          sort=1,
        );
        { dashboard: dashboard.addTemplate(t), selectorHash: selectorHash { [label]: '$' + label } },
    aggregationSet.labels,
    { dashboard: dashboard, selectorHash: aggregationSet.selector }
  );

local multiburnRateAlertsDashboard(
  sliType,
  aggregationSet,
      ) =

  local title =
    if sliType == 'apdex' then
      aggregationSet.name + ' Apdex SLO Analysis'
    else
      aggregationSet.name + ' Error SLO Analysis';

  local dashboardInitial =
    basic.dashboard(
      title,
      tags=['alert-target', 'general'],
    );

  local dashboardAndSelector =
    generateTemplatesAndSelectorHash(sliType, aggregationSet, dashboardInitial);

  local dashboardWithTemplates = dashboardAndSelector.dashboard.addTemplate(
    template.custom(
      'proposed_slo',
      'NaN,0.9,0.95,0.99,0.995,0.999,0.9995,0.9999',
      'NaN',
    )
  );

  local selectorHash = dashboardAndSelector.selectorHash;

  local sloMetricName = if sliType == 'apdex' then
    apdexSLOMetric
  else
    errorSLOMetric;
  local slaQuery =
    'avg(%s{monitor="global",type="$type"}) by (type)' % [sloMetricName];

  local pairFunction = if sliType == 'apdex' then apdexBurnRatePair else errorBurnRatePair;

  local oneHourBurnRateCombinations = pairFunction(
    aggregationSet=aggregationSet,
    shortDuration='5m',
    longDuration='1h',
    selectorHash=selectorHash
  );

  local sixHourBurnRateCombinations = pairFunction(
    aggregationSet=aggregationSet,
    shortDuration='30m',
    longDuration='6h',
    selectorHash=selectorHash
  );

  local statusDescriptionPanel = statusDescription.apdexStatusDescriptionPanel('SLO Analysis', selectorHash, aggregationSet=aggregationSet);

  dashboardWithTemplates.addPanels(
    layout.columnGrid([
      [
        statusDescriptionPanel,
        basic.slaStats(
          title='',
          description='Availability',
          query=slaQuery,
          legendFormat='{{ type }} service monitoring SLO',
        ),
        grafana.text.new(
          title='Help',
          mode='markdown',
          content=|||
            The SLO for this service will determine the thresholds (indicated by the dotted lines)
            in the following graphs. Over time, we expect these SLOs to become stricter (more nines) by
            improving the reliability of our service.

            **For more details of this technique, be sure to the Alerting on SLOs chapter of the
            [Google SRE Workbook](https://landing.google.com/sre/workbook/chapters/alerting-on-slos/)**
          |||
        ),
      ],
    ], rowHeight=6, columnWidths=[6, 6, 12]) +
    layout.columnGrid([
      burnRatePanelWithHelp(
        title='Multi-window, multi-burn-rates',
        combinations=oneHourBurnRateCombinations + sixHourBurnRateCombinations,
        content=|||
          # Multi-window, multi-burn-rates

          The alert will fire when both of the green solid series cross the green dotted threshold, or
          both of the blue solid series cross the blue dotted threshold.
        |||,
        stableId='multiwindow-multiburnrate',
      ),
      burnRatePanelWithHelp(
        title='Single window, 1h/5m burn-rates',
        combinations=oneHourBurnRateCombinations,
        content=|||
          # Single window, 1h/5m burn-rates

          Removing the 6h/30m burn-rates, this shows the same data over the 1h/5m burn-rates.

          The alert will fire when the solid lines cross the dotted threshold.
        |||,
      ),
      burnRatePanelWithHelp(
        title='Single window, 6h/30m burn-rates',
        combinations=sixHourBurnRateCombinations,
        content=|||
          # Single window, 6h/30m burn-rates

          Removing the 1h/5m burn-rates, this shows the same data over the 6h/30m burn-rates.

          The alert will fire when the solid lines cross the dotted threshold.
        |||
      ),
      burnRatePanelWithHelp(
        title='Single window, 1h/5m burn-rates, no thresholds',
        combinations=oneHourBurnRateCombinations[:2],
        content=|||
          # Single window, 1h/5m burn-rates, no thresholds

          Since the threshold can be relatively high, removing it can help visualise the current values better.
        |||
      ),
      burnRatePanelWithHelp(
        title='Single window, 6h/30m burn-rates, no thresholds',
        combinations=sixHourBurnRateCombinations[:2],
        content=|||
          # Single window, 6h/30m burn-rates, no thresholds

          Since the threshold can be relatively high, removing it can help visualise the current values better.
        |||
      ),
    ], columnWidths=[18, 6], rowHeight=10, startRow=100)
  )
  .trailer()
  + {
    links+: platformLinks.triage,
  };

local aggregationSetsForSLOAnalysisDashboards =
  std.filter(
    function(aggregationSet)
      aggregationSet.generateSLODashboards,
    std.objectValues(aggregationSets)
  );

std.foldl(
  function(memo, aggregationSet)
    memo {
      [aggregationSet.id + '_slo_apdex']: multiburnRateAlertsDashboard(
        sliType='apdex',
        aggregationSet=aggregationSet,
      ),
      [aggregationSet.id + '_slo_error']: multiburnRateAlertsDashboard(
        sliType='error',
        aggregationSet=aggregationSet,
      ),
    },
  aggregationSetsForSLOAnalysisDashboards,
  {}
)
