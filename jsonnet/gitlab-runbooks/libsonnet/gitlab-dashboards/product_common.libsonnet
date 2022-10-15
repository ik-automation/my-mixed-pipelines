local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local link = grafana.link;
local graphPanel = grafana.graphPanel;
local graphite = grafana.graphite;

{

  productDashboardLink()::
    link.dashboards(
      title='Stage Performance',
      tags='product performance',
      asDropdown=true,
      icon='dashboard',
    ),

  pageDetailLink()::
    link.dashboards(
      title='',
      tags='page summary',
      asDropdown=false,
      icon='external link',
      url='https://dashboards.gitlab.net/d/000000043/sitespeed-page-summary?orgId=1',
    ),

  pageDetail(title, page_alias, url)::

    local graphite_datasource = 'sitespeed';

    graphPanel.new(
      title,
      datasource=graphite_datasource,
      description=url,
      lines=true,
      fill=0,
      pointradius=2,
      nullPointMode='connected',
      legend_alignAsTable=true,
      legend_avg=true,
      legend_min=true,
      legend_max=true,
      legend_current=true,
      legend_values=true,
    ).addSeriesOverride({
      alias: 'LastVisualChange',
      color: '#E0B400',
      fillBelowTo: 'FirstVisualChange',
      lines: false,
    }).resetYaxes()
    .addYaxis(
      format='ms',
    ).addYaxis(
      format='short',
    ).addTarget(
      graphite.target(
        'aliasByNode(sitespeed_io.desktop.pageSummary.gitlab_com.' + page_alias + '.chrome.cable.browsertime.statistics.visualMetrics.FirstVisualChange.$function, 10)'
      ),
    ).addTarget(
      graphite.target(
        'aliasByNode(sitespeed_io.desktop.pageSummary.gitlab_com.' + page_alias + '.chrome.cable.browsertime.statistics.visualMetrics.LastVisualChange.$function, 10)'
      ),
    ).addTarget(
      graphite.target(
        'aliasByNode(sitespeed_io.desktop.pageSummary.gitlab_com.' + page_alias + '.chrome.cable.browsertime.statistics.timings.largestContentfulPaint.renderTime.$function, 10)'
      ),
    ),
}
