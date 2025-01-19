local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local template = grafana.template;
local productCommon = import 'gitlab-dashboards/product_common.libsonnet';

basic.dashboard(
  title='Performance - Create',
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
    content='### Synthetic tests of GitLab.com pages for the Create group.\n\nFor more information, please see: https://about.gitlab.com/handbook/product/product-processes/#page-load-performance-metrics\n\n\n\n',
  ), gridPos={ h: 3, w: 24, x: 0, y: 0 }
).addPanel(
  row.new(title='Soure Code'), gridPos={ x: 0, y: 1000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('MR List', 'SourceCode_MR_List', 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests'),
      productCommon.pageDetail('MR Detail - Small', 'SourceCode_MR_Small', 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/34944'),
      productCommon.pageDetail('MR Detail - Large', 'SourceCode_MR_Large', 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/22439'),
      productCommon.pageDetail('Repo Nav - Small', 'SourceCode_Repo_Small', 'https://gitlab.com/gitlab-org/language-tools/go/linters/goargs'),
      productCommon.pageDetail('Repo Nav - Large', 'SourceCode_Repo_Large', 'https://gitlab.com/gitlab-org/gitlab/-/tree/master'),
    ],
    startRow=1001,
  ),
).addPanel(
  row.new(title='Editor'), gridPos={ x: 0, y: 2000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Snippets - Explore', 'Editor_Snippets_Explore', 'https://gitlab.com/explore/snippets'),
      productCommon.pageDetail('Snippets - Textual', 'Editor_Snippets_Textual', 'https://gitlab.com/snippets/1985939'),
      productCommon.pageDetail('Snippets - Markdown', 'Editor_Snippets_Markdown', 'https://gitlab.com/snippets/1985940'),
      productCommon.pageDetail('Snippets - Multi-file', 'Editor_Snippets_Multifile', 'https://gitlab.com/snippets/2020132'),
      productCommon.pageDetail('WebIDE - about.gitlab.com', 'Editor_WebIDE_about_repo', 'https://gitlab.com/-/ide/project/gitlab-com/www-gitlab-com/edit/master/-/'),
      productCommon.pageDetail('WebIDE - Team page', 'Editor_WebIDE_team_page', 'https://gitlab.com/-/ide/project/gitlab-com/www-gitlab-com/edit/master/-/data/team.yml'),
      productCommon.pageDetail('Single File Editor - Team.yml', 'Editor_SingleFile_team_page', 'https://gitlab.com/gitlab-com/www-gitlab-com/-/edit/master/data/team.yml'),
    ],
    startRow=2001,
  ),
).addPanel(
  row.new(title='Knowledge'), gridPos={ x: 0, y: 3000, w: 24, h: 1 }
).addPanels(
  layout.grid(
    [
      productCommon.pageDetail('Design - Collection', 'Knowledge_Design_Collection', 'https://gitlab.com/gitlab-com/create-knowledge-load-performance-tests/-/issues/1/designs'),
      productCommon.pageDetail('Design - Single Image', 'Knowledge_Design_Single', 'https://gitlab.com/gitlab-com/create-knowledge-load-performance-tests/-/issues/1/designs/10-2500x1667.jpg'),
      productCommon.pageDetail('Wiki - History', 'Knowledge_Wiki_History', 'https://gitlab.com/gitlab-com/create-knowledge-load-performance-tests/-/wikis/many-changes/history'),
      productCommon.pageDetail('Wiki - Pages', 'Knowledge_Wiki_Pages', 'https://gitlab.com/gitlab-com/create-knowledge-load-performance-tests/-/wikis/pages'),
      productCommon.pageDetail('Wiki - AsciiDoc', 'Knowledge_Wiki_AsciiDoc', 'https://gitlab.com/gitlab-com/create-knowledge-load-performance-tests/-/wikis/formats/asciidoc/formatted-100kb'),
      productCommon.pageDetail('Wiki - Page 5', 'Knowledge_Wiki_Page5', 'https://gitlab.com/gitlab-com/create-knowledge-load-performance-tests/-/wikis/pages?page=5'),
      productCommon.pageDetail('Wiki - RDoc', 'Knowledge_Wiki_RDoc', 'https://gitlab.com/gitlab-com/create-knowledge-load-performance-tests/-/wikis/formats/rdoc/formatted-100kb'),
      productCommon.pageDetail('Wiki - Markdown', 'Knowledge_Wiki_Markdown', '\t\thttps://gitlab.com/gitlab-com/create-knowledge-load-performance-tests/-/wikis/formats/markdown/formatted-100kb'),
      productCommon.pageDetail('Wiki - Org', 'Knowledge_Wiki_Org', 'https://gitlab.com/gitlab-com/create-knowledge-load-performance-tests/-/wikis/formats/org/formatted-100kb'),
    ],
    startRow=3001,
  ),
)
