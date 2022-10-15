local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local template = grafana.template;
local productCommon = import 'gitlab-dashboards/product_common.libsonnet';

basic.dashboard(
  title='Performance - Plan',
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
    content='### Synthetic tests of GitLab.com pages for the Plan group.\n\nFor more information, please see: https://about.gitlab.com/handbook/product/product-processes/#page-load-performance-metrics\n\n\n\n',
  ), gridPos={ h: 3, w: 24, x: 0, y: 0 }
).addPanel(
  row.new(title='Project Management'), gridPos={ x: 0, y: 1000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Issues - List', 'ProjectManagement_Issues_List', 'https://gitlab.com/groups/gitlab-org/-/issues'),
      productCommon.pageDetail('Issues - Detail - Small', 'ProjectManagement_Issues_Detail_Small', 'https://gitlab.com/gitlab-org/gitlab/-/issues/207496'),
      productCommon.pageDetail('Issues - Detail - Large', 'ProjectManagement_Issues_Detail_Large', 'https://gitlab.com/gitlab-org/gitlab/-/issues/14972'),
      productCommon.pageDetail('Issues - Board Detail', 'ProjectManagement_Boards', 'https://gitlab.com/groups/gitlab-org/-/boards/1235826?&label_name[]=devops%3A%3Aplan&label_name[]=group%3A%3Aproject%20management'),
      productCommon.pageDetail('Issues - Milestone Detail - Small', 'ProjectManagement_Milestone_Small', 'https://gitlab.com/gitlab-org/plan/-/milestones/1'),
      productCommon.pageDetail('Issues - Milestone Detail - Large', 'ProjectManagement_Milestone_Large', 'https://gitlab.com/groups/gitlab-org/-/milestones/51'),
    ],
    startRow=1001,
  ),
).addPanel(
  row.new(title='Product Planning'), gridPos={ x: 0, y: 2000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Epics - Detail', 'PortfolioManagement_Epics', 'https://gitlab.com/groups/gitlab-org/-/epics/3003'),
      productCommon.pageDetail('Roadmap - Small', 'PortfolioManagement_Roadmaps_Small', 'https://gitlab.com/groups/gitlab-com/support/-/roadmap'),
      productCommon.pageDetail('Roadmap - Large', 'PortfolioManagement_Roadmaps_Large', 'https://gitlab.com/groups/gitlab-org/-/roadmap'),
    ],
    startRow=2001,
  ),
).addPanel(
  row.new(title='Certify'), gridPos={ x: 0, y: 3000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Requirements - List', 'Certify_Requirements_List', 'https://gitlab.com/gitlab-org/gitlab/-/requirements_management/requirements'),
    ],
    startRow=3001,
  ),
)
