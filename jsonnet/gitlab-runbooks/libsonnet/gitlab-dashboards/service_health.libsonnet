local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local colorScheme = import 'grafana/color_scheme.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';

local activeAlertsPanel(selector, title='Active Alerts') =
  local formatConfig = {
    selector: selector,
  };

  grafana.tablePanel.new(
    title,
    datasource='$PROMETHEUS_DS',
    styles=[
      {
        type: 'hidden',
        pattern: 'Time',
        alias: 'Time',
      },
      {
        unit: 'short',
        type: 'string',
        alias: 'Alert',
        decimals: 2,
        pattern: 'alertname',
        mappingType: 2,
        link: true,
        linkUrl: 'https://alerts.gitlab.net/#/alerts?filter=%7Balertname%3D%22${__cell}%22%2C%20env%3D%22${environment}%22%7D',
        linkTooltip: 'Open alertmanager',
      },
      {
        unit: 'short',
        type: 'number',
        alias: 'Score',
        decimals: 0,
        colors: [
          colorScheme.warningColor,
          colorScheme.errorColor,
          colorScheme.criticalColor,
        ],
        colorMode: 'row',
        pattern: 'Value',
        thresholds: [
          '2',
          '3',
        ],
        mappingType: 1,
      },
    ],
  )
  .addTarget(  // Alert scoring
    promQuery.target(
      |||
        sort(
          max(
            ALERTS{%(selector)s, severity="s1", alertstate="firing"} * 4
            or
            ALERTS{%(selector)s, severity="s2", alertstate="firing"} * 3
            or
            ALERTS{%(selector)s, severity="s3", alertstate="firing"} * 2
            or
            ALERTS{%(selector)s, alertstate="firing"}
          ) by (environment, alertname, severity)
        )
      ||| % formatConfig,
      format='table',
      instant=true
    )
  );

{
  activeAlertsPanel(selector, title='Active Alerts'):: activeAlertsPanel(selector, title=title),

}
