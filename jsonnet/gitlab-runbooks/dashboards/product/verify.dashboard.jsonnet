local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local template = grafana.template;
local productCommon = import 'gitlab-dashboards/product_common.libsonnet';

basic.dashboard(
  title='Performance - Verify',
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
    content='### Synthetic tests of GitLab.com pages for the Verify group.\n\nFor more information, please see: https://about.gitlab.com/handbook/product/product-processes/#page-load-performance-metrics\n\n\n\n',
  ), gridPos={ h: 3, w: 24, x: 0, y: 0 }
).addPanel(
  row.new(title='Continuous Integration'), gridPos={ x: 0, y: 1000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Pipeline - List', 'Verify_Pipeline_List', 'https://gitlab.com/gitlab-org/gitlab/-/pipelines'),
      productCommon.pageDetail('Pipeline - Filtered List', 'Verify_Pipeline_ListFiltered', 'https://gitlab.com/gitlab-org/gitlab/-/pipelines?page=1&scope=all&username=stanhu&ref=master'),
      productCommon.pageDetail('Pipeline - Schedules', 'Verify_Pipeline_Schedules', 'https://gitlab.com/gitlab-org/gitlab/-/pipeline_schedules'),
      productCommon.pageDetail('Pipeline - Charts', 'Verify_Pipeline_Charts', 'https://gitlab.com/gitlab-org/gitlab/-/pipelines/charts'),
      productCommon.pageDetail('Pipeline - View', 'Verify_Pipeline_View', 'https://gitlab.com/gitlab-org/gitlab/-/tree/master'),
      productCommon.pageDetail('Pipeline - DAG', 'Verify_Pipeline_DAG', 'https://gitlab.com/gitlab-org/gitlab/-/pipelines/145395337/dag'),
      productCommon.pageDetail('Job - List', 'Verify_Job_List', 'https://gitlab.com/gitlab-org/gitlab/-/jobs'),
      productCommon.pageDetail('Job - Detail', 'Verify_Job_Detail', 'https://gitlab.com/gitlab-org/gitlab/-/jobs/549614535'),
    ],
    startRow=1001,
  ),
).addPanel(
  row.new(title='Testing'), gridPos={ x: 0, y: 2000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Code Quality', 'Verify_Pipeline_CodeQuality', 'https://gitlab.com/gitlab-org/gitlab/-/pipelines/145395337/codequality_report'),
      productCommon.pageDetail('Code Coverage', 'Verify_Testing_CodeCoverageGraph', 'https://gitlab.com/gitlab-org/gitlab/-/graphs/master/charts'),
    ],
    startRow=3001,
  ),
)
