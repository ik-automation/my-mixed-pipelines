local thresholds = import './thresholds.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local seriesOverrides = import 'grafana/series_overrides.libsonnet';
local singleMetricRow = import 'key-metric-panels/single-metric-row.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local misc = import 'utils/misc.libsonnet';
local objects = import 'utils/objects.libsonnet';

local row = grafana.row;

local ignoreZero(query) = '%s > 0' % [query];

local getLatencyPercentileForService(serviceType) =
  local service = if serviceType == null then {} else metricsCatalog.getService(serviceType);

  if std.objectHas(service, 'contractualThresholds') && std.objectHas(service.contractualThresholds, 'apdexRatio') then
    service.contractualThresholds.apdexRatio
  else
    0.95;

local getMarkdownDetailsForSLI(sli, sliSelectorHash) =
  local items = std.prune([
    (
      if sli.description != '' then
        |||
          ### Description

          %(description)s
        ||| % {
          description: sli.description,
        }
      else
        null
    ),
    (
      if sli.hasToolingLinks() then
        // We pass the selector hash to the tooling links they may
        // be used to customize the links
        local toolingOptions = { prometheusSelectorHash: sliSelectorHash };
        |||
          ### Observability Tools

          %(links)s
        ||| % {
          links: toolingLinks.generateMarkdown(sli.getToolingLinks(), toolingOptions),
        }
      else
        null
    ),
  ]);

  std.join('\n\n', items);

local sliOverviewMatrixRow(
  serviceType,
  sli,
  startRow,
  selectorHash,
  aggregationSet,
  legendFormatPrefix,
  expectMultipleSeries,
      ) =
  local typeSelector = if serviceType == null then {} else { type: serviceType };
  local selectorHashWithExtras = selectorHash { component: sli.name } + typeSelector;
  local formatConfig = {
    serviceType: serviceType,
    sliName: sli.name,
    legendFormatPrefix: if legendFormatPrefix != '' then legendFormatPrefix else sli.name,
  };

  local columns =
    singleMetricRow.row(
      serviceType=serviceType,
      aggregationSet=aggregationSet,
      selectorHash=selectorHashWithExtras,
      titlePrefix='%(sliName)s SLI' % formatConfig,
      stableIdPrefix='sli-%(sliName)s' % formatConfig,
      legendFormatPrefix='%(legendFormatPrefix)s' % formatConfig,
      expectMultipleSeries=expectMultipleSeries,
      showApdex=sli.hasApdex(),
      showErrorRatio=sli.hasErrorRate(),
      showOpsRate=true,
      includePredictions=false
    )
    +
    (
      local markdown = getMarkdownDetailsForSLI(sli, selectorHash);
      if markdown != '' then
        [[
          grafana.text.new(
            title='Details',
            mode='markdown',
            content=markdown,
          ),
        ]]
      else
        []
    );

  layout.splitColumnGrid(columns, [7, 1], startRow=startRow);

local sliDetailLatencyPanel(
  title=null,
  sli=null,
  serviceType=null,
  selector=null,
  aggregationLabels='',
  logBase=10,
  legendFormat='%(percentile_humanized)s %(sliName)s',
  min=0.01,
  intervalFactor=2,
  withoutLabels=[],
      ) =
  local percentile = getLatencyPercentileForService(serviceType);
  local formatConfig = { percentile_humanized: 'p%g' % [percentile * 100], sliName: sli.name };

  basic.latencyTimeseries(
    title=(if title == null then 'Estimated %(percentile_humanized)s latency for %(sliName)s' + sli.name else title) % formatConfig,
    query=ignoreZero(sli.apdex.percentileLatencyQuery(
      percentile=percentile,
      aggregationLabels=aggregationLabels,
      selector=selector,
      rangeInterval='$__interval',
      withoutLabels=withoutLabels,
    )),
    logBase=logBase,
    legendFormat=legendFormat % formatConfig,
    min=min,
    intervalFactor=intervalFactor,
  ) + {
    thresholds: [
      thresholds.errorLevel('gt', sli.apdex.toleratedThreshold),
      thresholds.warningLevel('gt', sli.apdex.satisfiedThreshold),
    ],
  };

local sliDetailOpsRatePanel(
  title=null,
  serviceType=null,
  sli=null,
  selector=null,
  aggregationLabels='',
  legendFormat='%(sliName)s operations',
  intervalFactor=2,
  withoutLabels=[],
      ) =

  basic.timeseries(
    title=if title == null then 'RPS for ' + sli.name else title,
    query=ignoreZero(sli.requestRate.aggregatedRateQuery(
      aggregationLabels=aggregationLabels,
      selector=selector,
      rangeInterval='$__interval',
      withoutLabels=withoutLabels,
    )),
    legendFormat=legendFormat % { sliName: sli.name },
    intervalFactor=intervalFactor,
    yAxisLabel='Requests per Second'
  );

local sliDetailErrorRatePanel(
  title=null,
  sli=null,
  selector=null,
  aggregationLabels='',
  legendFormat='%(sliName)s errors',
  intervalFactor=2,
  withoutLabels=[],
      ) =

  basic.timeseries(
    title=if title == null then 'Errors for ' + sli.name else title,
    query=ignoreZero(sli.errorRate.aggregatedRateQuery(
      aggregationLabels=aggregationLabels,
      selector=selector,
      rangeInterval='$__interval',
      withoutLabels=withoutLabels,
    )),
    legendFormat=legendFormat % { sliName: sli.name },
    intervalFactor=intervalFactor,
    yAxisLabel='Errors',
    decimals=2,
  );
{
  // Generates a grid/matrix of SLI data for the given service/stage
  sliMatrixForService(
    title,
    serviceType,
    aggregationSet,
    startRow,
    selectorHash,
    legendFormatPrefix='',
    expectMultipleSeries=false
  )::
    local service = metricsCatalog.getService(serviceType);
    [
      row.new(title=title, collapse=false) { gridPos: { x: 0, y: startRow, w: 24, h: 1 } },
    ] +
    std.prune(
      std.flattenArrays(
        std.mapWithIndex(
          function(i, sliName)
            sliOverviewMatrixRow(
              serviceType=serviceType,
              aggregationSet=aggregationSet,
              sli=service.serviceLevelIndicators[sliName],
              selectorHash=selectorHash { type: serviceType },
              startRow=startRow + 1 + i * 10,
              legendFormatPrefix=legendFormatPrefix,
              expectMultipleSeries=expectMultipleSeries,
            ), std.objectFields(service.serviceLevelIndicators)
        )
      )
    ),

  sliMatrixAcrossServices(
    title,
    serviceTypes,
    aggregationSet,
    startRow,
    selectorHash,
    legendFormatPrefix='',
    expectMultipleSeries=false,
    sliFilter=function(x) x,
  )::

    local allSLIsForServices = std.flatMap(
      function(serviceType) std.objectValues(metricsCatalog.getService(serviceType).serviceLevelIndicators),
      serviceTypes
    );
    local filteredSLIs = std.filter(sliFilter, allSLIsForServices);
    local slis = std.foldl(
      function(memo, sli)
        memo { [sli.name]: sli },
      filteredSLIs,
      {}
    );

    layout.titleRowWithPanels(
      title=title,
      collapse=true,
      startRow=startRow,
      panels=layout.rows(
        std.prune(
          std.mapWithIndex(
            function(i, sliName)
              local sli = slis[sliName];

              if sliFilter(sli) then
                sliOverviewMatrixRow(
                  serviceType=null,
                  aggregationSet=aggregationSet,
                  sli=sli,
                  selectorHash=selectorHash,
                  startRow=startRow + 1 + i * 10,
                  legendFormatPrefix=legendFormatPrefix,
                  expectMultipleSeries=expectMultipleSeries,
                )
              else
                [],
            std.objectFields(slis)
          )
        )
      )
    ),

  sliDetailMatrix(
    serviceType,
    sliName,
    selectorHash,
    aggregationSets,
    minLatency=0.01
  )::
    local service = metricsCatalog.getService(serviceType);
    local sli = service.serviceLevelIndicators[sliName];

    local staticLabelNames = if std.objectHas(sli, 'staticLabels') then std.objectFields(sli.staticLabels) else [];

    // Note that we always want to ignore `type` filters, since the metricsCatalog selectors will
    // already have correctly filtered labels to ensure the right values, and if we inject the type
    // we may lose metrics 'proxied' from nodes with other types
    local filteredSelectorHash = selectors.without(selectorHash, [
      'type',
    ] + staticLabelNames);

    row.new(title='🔬 SLI Detail: %(sliName)s' % { sliName: sliName }, collapse=true)
    .addPanels(
      std.flattenArrays(
        std.mapWithIndex(
          function(index, aggregationSet)
            layout.singleRow(
              std.prune(
                [
                  if sli.hasHistogramApdex() then
                    sliDetailLatencyPanel(
                      title='Estimated %(percentile_humanized)s ' + sliName + ' Latency - ' + aggregationSet.title,
                      serviceType=serviceType,
                      sli=sli,
                      selector=filteredSelectorHash + aggregationSet.selector,
                      legendFormat='%(percentile_humanized)s ' + aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                      min=minLatency
                    )
                  else
                    null,

                  if misc.isPresent(aggregationSet.aggregationLabels) && sli.hasApdex() && std.objectHasAll(sli.apdex, 'apdexAttribution') then
                    basic.percentageTimeseries(
                      title='Apdex attribution for ' + sliName + ' Latency - ' + aggregationSet.title,
                      description='Attributes apdex downscoring',
                      query=sli.apdex.apdexAttribution(
                        aggregationLabel=aggregationSet.aggregationLabels,
                        selector=filteredSelectorHash + aggregationSet.selector,
                        rangeInterval='$__interval',
                      ),
                      legendFormat=aggregationSet.legendFormat % { sliName: sliName },
                      intervalFactor=3,
                      decimals=2,
                      linewidth=1,
                      fill=4,
                      stack=true,
                    )
                    .addSeriesOverride(seriesOverrides.negativeY)
                  else
                    null,

                  if sli.hasErrorRate() then
                    sliDetailErrorRatePanel(
                      title=sliName + ' Errors - ' + aggregationSet.title,
                      sli=sli,
                      legendFormat=aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                      selector=filteredSelectorHash + aggregationSet.selector,
                    )
                  else
                    null,

                  if sli.hasAggregatableRequestRate() then
                    sliDetailOpsRatePanel(
                      title=sliName + ' RPS - ' + aggregationSet.title,
                      sli=sli,
                      selector=filteredSelectorHash + aggregationSet.selector,
                      legendFormat=aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels
                    )
                  else
                    null,
                ]
              ),
              startRow=index * 10
            ),
          aggregationSets
        )
      )
    ),

  sliDetailMatrixAcrossServices(
    sli,
    selectorHash,
    aggregationSets,
    minLatency=0.01
  )::
    // Note that we always want to ignore `type` filters, since the metricsCatalog selectors will
    // already have correctly filtered labels to ensure the right values, and if we inject the type
    // we may lose metrics 'proxied' from nodes with other types
    local staticLabelNames = if std.objectHas(sli, 'staticLabels') then std.objectFields(sli.staticLabels) else [];
    local withoutLabels = ['type'] + staticLabelNames;
    local filteredSelectorHash = selectors.without(selectorHash, withoutLabels);

    row.new(title='🔬 SLI Detail: %(sliName)s' % { sliName: sli.name }, collapse=true)
    .addPanels(
      std.flattenArrays(
        std.mapWithIndex(
          function(index, aggregationSet)
            local combinedSelector = aggregationSet.selector + filteredSelectorHash;

            layout.singleRow(
              std.prune(
                [
                  if sli.hasHistogramApdex() then
                    sliDetailLatencyPanel(
                      title='Estimated %(percentile_humanized)s ' + sli.name + ' Latency - ' + aggregationSet.title,
                      sli=sli,
                      selector=combinedSelector,
                      legendFormat='%(percentile_humanized)s ' + aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                      withoutLabels=withoutLabels,
                      min=minLatency,
                    )
                  else
                    null,

                  if misc.isPresent(aggregationSet.aggregationLabels) && sli.hasApdex() && std.objectHasAll(sli.apdex, 'apdexAttribution') then
                    basic.percentageTimeseries(
                      title='Apdex attribution for ' + sli.name + ' Latency - ' + aggregationSet.title,
                      description='Attributes apdex downscoring',
                      query=sli.apdex.apdexAttribution(
                        aggregationLabel=aggregationSet.aggregationLabels,
                        selector=combinedSelector,
                        rangeInterval='$__interval',
                        withoutLabels=withoutLabels,
                      ),
                      legendFormat=aggregationSet.legendFormat % { sliName: sli.name },
                      intervalFactor=3,
                      decimals=2,
                      linewidth=1,
                      fill=4,
                      stack=true,
                    )
                    .addSeriesOverride(seriesOverrides.negativeY)
                  else
                    null,

                  if sli.hasErrorRate() then
                    sliDetailErrorRatePanel(
                      title=sli.name + ' Errors - ' + aggregationSet.title,
                      sli=sli,
                      legendFormat=aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                      selector=combinedSelector,
                      withoutLabels=withoutLabels,
                    )
                  else
                    null,

                  if sli.hasAggregatableRequestRate() then
                    sliDetailOpsRatePanel(
                      title=sli.name + ' RPS - ' + aggregationSet.title,
                      sli=sli,
                      selector=combinedSelector,
                      legendFormat=aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                      withoutLabels=withoutLabels,
                    )
                  else
                    null,
                ]
              ),
              startRow=index * 10
            ),
          aggregationSets
        )
      )
    ),

  autoDetailRows(serviceType, selectorHash, startRow)::
    local s = self;
    local service = metricsCatalog.getService(serviceType);
    local serviceLevelIndicators = service.listServiceLevelIndicators();
    local serviceLevelIndicatorsFiltered = std.filter(function(c) c.supportsDetails(), serviceLevelIndicators);

    layout.grid(
      std.mapWithIndex(
        function(i, sli)
          local aggregationSets =
            [
              { title: 'Overall', aggregationLabels: '', selector: {}, legendFormat: 'overall' },
            ] +
            std.map(function(c) { title: 'per ' + c, aggregationLabels: c, selector: { [c]: { ne: '' } }, legendFormat: '{{' + c + '}}' }, sli.significantLabels);

          s.sliDetailMatrix(serviceType, sli.name, selectorHash, aggregationSets),
        serviceLevelIndicatorsFiltered
      )
      , cols=1, startRow=startRow
    ),

  autoDetailRowsAcrossServices(
    serviceTypes,
    selectorHash,
    startRow,
    sliFilter=function(x) x,
  )::
    local s = self;
    local slis = objects.fromPairs(
      std.filter(
        function(pair) pair[1].supportsDetails() && sliFilter(pair[1]),
        std.flattenArrays(
          std.map(
            function(serviceType) objects.toPairs(metricsCatalog.getService(serviceType).serviceLevelIndicators),
            serviceTypes
          ),
        ),
      ),
    );

    layout.grid(
      std.mapWithIndex(
        function(i, sliName)
          local sli = slis[sliName];

          local aggregationSets =
            [
              { title: 'Overall', aggregationLabels: '', selector: {}, legendFormat: 'overall' },
            ] +
            std.map(function(c) { title: 'per ' + c, aggregationLabels: c, selector: { [c]: { ne: '' } }, legendFormat: '{{' + c + '}}' }, sli.significantLabels);

          s.sliDetailMatrixAcrossServices(sli, selectorHash, aggregationSets),
        std.objectFields(slis)
      )
      , cols=1, startRow=startRow
    ),
}
