local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local template = grafana.template;
local productCommon = import 'gitlab-dashboards/product_common.libsonnet';

basic.dashboard(
  title='Performance - Secure',
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
    content='### Synthetic tests of GitLab.com pages for the Secure group.\n\nFor more information, please see: https://about.gitlab.com/handbook/product/product-processes/#page-load-performance-metrics\n\n\n\n',
  ), gridPos={ h: 3, w: 24, x: 0, y: 0 }
).addPanel(
  row.new(title='Threat Insights'), gridPos={ x: 0, y: 1000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Merge Request', 'Secure_Merge_Request', 'https://gitlab.com/gitlab-examples/security/security-reports/-/merge_requests/39'),
      productCommon.pageDetail('Instance Security Dashboard', 'Secure_Instance_Security_Dashboard', 'https://gitlab.com/-/security/dashboard'),
      productCommon.pageDetail('Instance Vulnerability Report', 'Secure_Instance_Vulnerability_Report', 'https://gitlab.com/-/security/vulnerabilities'),
      productCommon.pageDetail('Instance Vulnerability Report', 'Secure_Instance_Dashboard_Settings', ' https://gitlab.com/-/security/dashboard/settings'),
      productCommon.pageDetail('Group Security Dashboard', 'Secure_Group_Security_Dashboard', 'https://gitlab.com/groups/gitlab-examples/security/-/security/dashboard'),
      productCommon.pageDetail('Group Vulnerability Report', 'Secure_Group_Vulnerability_Report', 'https://gitlab.com/groups/gitlab-examples/security/-/security/vulnerabilities'),
      productCommon.pageDetail('Project Security Dashboard', 'Secure_Project_Security_Dashboard', 'https://gitlab.com/gitlab-examples/security/simply-simple-notes/-/security/dashboard'),
      productCommon.pageDetail('Project Vulnerability Report', 'Secure_Project_Vulnerability_Report', 'https://gitlab.com/gitlab-examples/security/simply-simple-notes/-/security/vulnerability_report'),
      productCommon.pageDetail('Vulnerability Details Page', 'Secure_Standalone_Vulnerability', 'https://gitlab.com/gitlab-examples/security/security-reports/-/security/vulnerabilities/26231'),
      productCommon.pageDetail('Security Configuration', 'Security_Configuration', 'https://gitlab.com/gitlab-examples/security/security-reports/-/security/configuration'),
    ],
    startRow=1001,
  ),
).addPanel(
  row.new(title='Composition Analysis'), gridPos={ x: 0, y: 2000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('License Compliance', 'Secure_License_Compliance', 'https://gitlab.com/gitlab-examples/security/security-reports/-/licenses#licenses'),
      productCommon.pageDetail('Dependency List', 'Secure_Dependency_List', 'https://gitlab.com/gitlab-examples/security/security-reports/-/dependencies'),
    ],
    startRow=2001,
  ),
).addPanel(
  row.new(title='DAST'), gridPos={ x: 0, y: 3000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('On-Demand Scans', 'On_Demand_Scans', 'https://gitlab.com/gitlab-examples/security/security-reports/-/on_demand_scans'),
      productCommon.pageDetail('DAST Profiles', 'DAST_Profiles', 'https://gitlab.com/gitlab-examples/security/security-reports/-/security/configuration/dast_scans'),
    ],
    startRow=3001,
  ),
).addPanel(
  row.new(title='SAST'), gridPos={ x: 0, y: 4000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('SAST Config UI', 'SAST_Config_UI', 'https://gitlab.com/gitlab-examples/security/security-reports/-/security/configuration/sast'),
    ],
    startRow=4001,
  ),
).addPanel(
  row.new(title='Fuzz Testing'), gridPos={ x: 0, y: 5000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('API Fuzzing Config UI', 'API_Fuzzing_Config_UI', 'https://gitlab.com/gitlab-examples/security/security-reports/-/security/configuration/api_fuzzing'),
    ],
    startRow=5001,
  ),
)
