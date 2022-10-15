local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local template = grafana.template;
local productCommon = import 'gitlab-dashboards/product_common.libsonnet';

basic.dashboard(
  title='Performance - Manage',
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
    content='### Synthetic tests of GitLab.com pages for the Manage group.\n\nFor more information, please see: https://about.gitlab.com/handbook/product/product-processes/#page-load-performance-metrics\n\n\n\n',
  ), gridPos={ h: 3, w: 24, x: 0, y: 0 }
).addPanel(
  row.new(title='Analytics'), gridPos={ x: 0, y: 1000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Value Stream Analytics', 'Analytics_Value_Stream', 'https://gitlab.com/gitlab-org/gitlab/-/value_stream_analytics'),
    ],
    startRow=1001,
  ),
).addPanel(
  row.new(title='Access'), gridPos={ x: 0, y: 2000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Groups - List', 'Access_Group_List', 'https://gitlab.com/dashboard/groups'),
      productCommon.pageDetail('Groups - View', 'Access_Group_View', 'https://gitlab.com/gitlab-org'),
    ],
    startRow=2001,
  ),
).addPanel(
  row.new(title='Import'), gridPos={ x: 0, y: 3000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Project - New', 'Import_Project_Creation', 'https://gitlab.com/projects/new'),
      productCommon.pageDetail('Import - GitHub', 'Import_Importer_Github', 'https://gitlab.com/import/github/new'),
      productCommon.pageDetail('Import - BitBucket Cloud', 'Import_Importer_BitbucketCloud', 'https://gitlab.com/import/bitbucket/status'),
      productCommon.pageDetail('import - BitBucket Server', 'Import_Importer_BitBucketServer', 'https://gitlab.com/import/bitbucket_server/new'),
      productCommon.pageDetail('Import - Fogbugz', 'Import_Importer_Fogbugz', 'https://gitlab.com/import/fogbugz/new'),
      productCommon.pageDetail('Import - Gitea', 'Import_Importer_Gitea', 'https://gitlab.com/import/gitea/new'),
      productCommon.pageDetail('Import - Manifest', 'Import_Importer_Manifest', 'https://gitlab.com/import/manifest/new'),
    ],
    startRow=3001,
  ),
)
