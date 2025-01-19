local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local template = grafana.template;
local productCommon = import 'gitlab-dashboards/product_common.libsonnet';

basic.dashboard(
  title='Performance - Monitor',
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
    content="### Synthetic tests of GitLab.com pages for the Monitor group.\n\nFor more information, please see: https://about.gitlab.com/handbook/product/product-processes/#page-load-performance-metrics. NOTE - these may be 403'ing, and thus unreliable!",
  ), gridPos={ h: 3, w: 24, x: 0, y: 0 }
).addPanel(
  row.new(title='Monitor'), gridPos={ x: 0, y: 1000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Metrics Dashboard', 'Monitor_Metrics', 'https://gitlab.com/gitlab-com/www-gitlab-com/-/environments/137/metrics'),
      productCommon.pageDetail('Logs - View', 'Monitor_Logs', 'https://gitlab.com/gitlab-com/www-gitlab-com/-/logs'),
      productCommon.pageDetail('Alert Management', 'Monitor_Alerts', 'https://gitlab.com/gitlab-com/www-gitlab-com/-/alert_management'),
      productCommon.pageDetail('Error Tracking', 'Monitor_Errors', 'https://gitlab.com/gitlab-com/www-gitlab-com/-/error_tracking'),
      productCommon.pageDetail('Cluster Dashboard', 'Monitor_Clusters', 'https://gitlab.com/gitlab-com/www-gitlab-com/-/clusters'),
    ],
    startRow=1001,
  ),
)
