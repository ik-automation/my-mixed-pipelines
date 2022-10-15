local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';

function(sli)
  local labels = {
    user_impacting: if sli.userImpacting then 'yes' else 'no',
  };

  local team = if sli.team != null then serviceCatalog.getTeam(sli.team) else null;
  local featureCategoryLabels = if sli.hasStaticFeatureCategory() then
    sli.staticFeatureCategoryLabels()
  else if sli.hasFeatureCategoryFromSourceMetrics() then
    // This indicates that there might be multiple
    // feature categories contributing to the component
    // that is alerting. This is not nescessarily
    // caused by a single feature category
    { feature_category: 'in_source_metrics' }
  else if !sli.hasFeatureCategory() then
    { feature_category: 'not_owned' };

  labels + featureCategoryLabels + (
    if team != null && team.issue_tracker != null then
      { incident_project: team.issue_tracker }
    else
      {}
  ) + (
    /**
     * When team.send_slo_alerts_to_team_slack_channel is configured in the service catalog
     * alerts will be sent to slack team alert channels in addition to the
     * usual locations
     */
    if team != null && team.send_slo_alerts_to_team_slack_channel then
      { team: sli.team }
    else
      {}
  )
