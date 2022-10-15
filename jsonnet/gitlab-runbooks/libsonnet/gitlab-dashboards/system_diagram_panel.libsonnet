local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local sliPromQL = import 'key-metric-panels/sli_promql.libsonnet';
local dependencies = import 'service-dependencies/service-dependencies.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local row = grafana.row;

local evaluator = import 'service-maturity/evaluator.libsonnet';
local levels = import 'service-maturity/levels.libsonnet';
local strings = import 'utils/strings.libsonnet';

local MERMAID_DIAGRAM_TEMPLATE =
  |||
    graph %(direction)s
      %(subgraphs)s

      %(dependencyList)s
  |||;

local generateMermaidSubgraphsForTier(tier, services) =
  |||
    subgraph %(tier)s
      %(serviceList)s
    end
  ||| % {
    tier: tier,
    serviceList: std.join('\n  ', services),
  };

local generateMermaidSubgraphs(services) =
  local servicesByTier = std.foldl(function(memo, service) std.mergePatch(memo, { [service.tier]: { [service.type]: true } }), services, {});
  local tiers = std.map(function(tier) generateMermaidSubgraphsForTier(tier, std.objectFields(servicesByTier[tier])), std.objectFields(servicesByTier));
  std.join('\n', tiers);

local generateMermaidDependencyForService(service) =
  if std.objectHas(service, 'serviceDependencies') then
    std.map(function(dep) '%s --> %s' % [service.type, dep], std.objectFields(service.serviceDependencies))
  else
    [];

local generateMermaidDependencyList(services) =
  local lines = std.flattenArrays(std.map(generateMermaidDependencyForService, services));
  std.join('\n', lines);

local generateMermaidDiagram(services, diagramOptions={}) =
  local direction = if std.objectHas(diagramOptions, 'direction') then diagramOptions.direction else 'TD';
  MERMAID_DIAGRAM_TEMPLATE % {
    subgraphs: generateMermaidSubgraphs(services),
    dependencyList: generateMermaidDependencyList(services),
    direction: direction,
  };

local systemDiagram(title, graphId, services, targets, diagramOptions) = {
  datasource: '$PROMETHEUS_DS',
  colors: diagramOptions.colors,
  composites: [],
  decimals: 3,
  format: 'percentunit',
  graphId: graphId,
  gridPos: {
    h: 21,
    w: 24,
    x: 0,
    y: 21,
  },
  init: {
    arrowMarkerAbsolute: true,
    cloneCssStyles: true,
    flowchart: {
      htmlLabels: true,
      useMaxWidth: true,
    },
    gantt: {
      barGap: 4,
      barHeight: 20,
      fontFamily: '"Open-Sans", "sans-serif"',
      fontSize: 11,
      gridLineStartPadding: 35,
      leftPadding: 75,
      numberSectionStyles: 3,
      titleTopMargin: 25,
      topPadding: 50,
    },
    logLevel: 3,
    sequenceDiagram: {
      actorMargin: 50,
      bottomMarginAdj: 1,
      boxMargin: 10,
      boxTextMargin: 5,
      diagramMarginX: 50,
      diagramMarginY: 10,
      height: 65,
      messageMargin: 35,
      mirrorActors: true,
      noteMargin: 10,
      useMaxWidth: true,
      width: 150,
    },
    startOnLoad: false,
  },
  interval: '',
  legend: {
    avg: true,
    current: true,
    gradient: {
      enabled: true,
      show: true,
    },
    max: true,
    min: true,
    show: false,
    total: true,
  },
  mappingType: 1,
  mappingTypes: [],
  maxDataPoints: 100,
  maxWidth: false,
  mermaidServiceUrl: '',
  metricCharacterReplacements: [],
  moddedSeriesVal: 0,
  mode: 'content',
  nullPointMode: 'connected',
  options: {
    content: generateMermaidDiagram(services, diagramOptions),
  },
  seriesOverrides: [],
  style: '',
  targets: targets,
  thresholds: diagramOptions.thresholds,
  title: title,
  type: 'jdbranham-diagram-panel',
  valueMaps: [],
  valueName: 'current',
  valueOptions: [
    'avg',
    'min',
    'max',
    'total',
    'current',
  ],
};

local errorDiagram(services, diagramOptions={}) =
  systemDiagram(
    title='System Diagram (Keyed by Error Rates)',
    graphId='diagram_errors',
    targets=[promQuery.target(
      sliPromQL.errorRatioQuery(aggregationSets.serviceSLIs, null, selectorHash={ environment: '$environment', stage: '$stage' }, range='$__range'),
      legendFormat='{{ type }}',
      instant=true
    )],
    services=services,
    diagramOptions={
      colors: [
        'rgba(50, 172, 45, 0.97)',
        'rgba(237, 129, 40, 0.89)',
        'rgba(245, 54, 54, 0.9)',
      ],
      thresholds: '0,0.001',
    } + diagramOptions
  );

local apdexDiagram(services, diagramOptions={}) =
  systemDiagram(
    title='System Diagram (Keyed by Apdex/Latency Scores)',
    graphId='diagram_apdex',
    targets=[promQuery.target(
      sliPromQL.apdexQuery(aggregationSets.serviceSLIs, null, { environment: '$environment', stage: '$stage' }, range='$__range'),
      legendFormat='{{ type }}',
      instant=true
    )],
    services=services,
    diagramOptions={
      colors: [
        'rgba(245, 54, 54, 0.9)',
        '#FF9830',
        '#73BF69',
      ],
      thresholds: '0.99,0.995,0.999',
    } + diagramOptions
  );

local maturityDiagram(services, diagramOptions={}) =
  systemDiagram(
    title='System Diagram (Keyed by Maturity Model)',
    graphId='diagram_maturity',
    targets=[],
    services=std.map(
      function(service)
        local level = evaluator.maxLevel(service, levels.getLevels());
        service {
          type: '%(service)s["%(serviceLabel)s"]' % {
            service: service.type,
            serviceLabel: '%s (%s)' % [service.type, level.name],
          },
        },
      services
    ),
    diagramOptions={
      colors: [],
      thresholds: '',
    } + diagramOptions
  );

local getServicesFor(serviceName) =
  local serviceNames = dependencies.listDownstreamServices(serviceName);
  [
    metricsCatalog.getService(serviceName)
    for serviceName in serviceNames
  ];

{
  systemDiagramRowForService(serviceName)::
    local services = getServicesFor(serviceName);

    row.new(title='🗺️ System Diagrams', collapse=true)
    .addPanels(layout.grid([
      errorDiagram(services),
      apdexDiagram(services),
      maturityDiagram(services),
    ], cols=1, rowHeight=10)),
  errorDiagram: errorDiagram,
  apdexDiagram: apdexDiagram,
  maturityDiagram: maturityDiagram,
}
