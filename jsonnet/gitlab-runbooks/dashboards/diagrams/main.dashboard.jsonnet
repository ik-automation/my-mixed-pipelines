local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local diagram = import 'gitlab-dashboards/system_diagram_panel.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local templates = import 'grafana/templates.libsonnet';
local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';
local evaluator = import 'service-maturity/evaluator.libsonnet';
local levels = import 'service-maturity/levels.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local markdown = import 'utils/markdown.libsonnet';

local options = {
  direction: 'LR',
};

local linkToServiceDashboard(name) =
  'https://dashboards.gitlab.net/d/%(uuid)s' % {
    uuid: toolingLinks.grafanaUid('%s/main.jsonnet' % name),
  };

local dependencyCell(dependencies) =
  std.join(
    ', ',
    std.map(
      function(dependencyName)
        local dependency = metricsCatalog.getService(dependencyName);
        '[%(name)s (%(level)s)](%(link)s)' % {
          name: dependencyName,
          level: evaluator.maxLevel(dependency, levels.getLevels()).name,
          link: linkToServiceDashboard(dependencyName),
        },
      std.sort(dependencies)
    )
  );

local maturityDependencyTable =
  local rows =
    std.map(
      function(serviceName)
        local service = metricsCatalog.getService(serviceName);
        [
          '[%s](%s)' % [serviceName, linkToServiceDashboard(serviceName)],
          evaluator.maxLevel(service, levels.getLevels()).name,
          dependencyCell(serviceCatalog.serviceGraph[service.type].outward),
          dependencyCell(serviceCatalog.serviceGraph[service.type].inward),
        ],
      std.sort(std.objectFields(serviceCatalog.serviceGraph))
    );
  basic.text(
    mode='markdown',
    content=markdown.generateTable(
      ['Service', 'Maturity level', 'Outward', 'Inward'],
      rows
    ),
  );

basic.dashboard(
  'Overview diagrams',
  tags=[],
  editable=false,
)
.addTemplate(templates.stage)
.addPanels([
  row.new(title='System Diagram (Keyed by Error Rates)', collapse=true)
  .addPanel(
    diagram.errorDiagram(metricsCatalog.services, options),
    gridPos={ x: 0, y: 0, w: 24, h: 20 }
  ),
])
.addPanels([
  row.new(title='System Diagram (Keyed by Apdex/Latency Scores)', collapse=true)
  .addPanel(
    diagram.apdexDiagram(metricsCatalog.services, options),
    gridPos={ x: 0, y: 1000, w: 24, h: 20 }
  ),
])
.addPanels([
  row.new(title='System Diagram (Keyed by Maturity Model)', collapse=true)
  .addPanel(
    diagram.maturityDiagram(metricsCatalog.services, options),
    gridPos={ x: 0, y: 2000, w: 24, h: 20 }
  )
  .addPanel(
    maturityDependencyTable,
    gridPos={ x: 0, y: 3000, w: 24, h: 20 }
  ),
])
.trailer()
