local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local template = grafana.template;
local productCommon = import 'gitlab-dashboards/product_common.libsonnet';

basic.dashboard(
  title='Performance - Release',
  time_from='now-30d',
  tags=['product performance'],
).addLink(
  productCommon.productDashboardLink(),
).addLink(
  productCommon.pageDetailLink(),
).addTemplate(
  template.interval('function', 'min, mean, median, p90, max', 'median'),
).addPanel(
  grafana.text.new(
    title='Overview',
    mode='markdown',
    content='### Synthetic tests of GitLab.com pages for the Release group.\n\nFor more information, please see: hhttps://about.gitlab.com/handbook/product/product-processes/#page-load-performance-metrics\n\n\n\n',
  ), gridPos={ h: 3, w: 24, x: 0, y: 0 }
).addPanel(
  row.new(title='Release Management'), gridPos={ x: 0, y: 1000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Releases - List', 'Release_Release_List', 'https://gitlab.com/gitlab-org/gitlab/-/releases'),
    ],
    startRow=1001,
  ),
)
