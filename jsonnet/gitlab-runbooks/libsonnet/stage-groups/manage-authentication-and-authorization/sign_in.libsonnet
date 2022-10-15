local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';

local signInMultiTimeSeries(title, queryConfig) =
  basic.multiTimeseries(
    title=title,
    format='short',
    stack=false,
    interval='',
    intervalFactor=5,
    queries=[
      { legendFormat: config.legend, query: 'sum by () (increase(' + config.metric + '{environment="$environment"}[$__interval]))' }
      for config in queryConfig
    ],
  );

local panels() =
  layout.rowGrid(
    'Sign-ins',
    [
      signInMultiTimeSeries(
        'Sessions', [
          { legend: 'Logins', metric: 'user_session_logins_total' },
          { legend: 'Invalid passwords', metric: 'gitlab_auth_user_password_invalid_total' },
        ]
      ),
      signInMultiTimeSeries(
        'Authentication', [
          { legend: 'Authenticated', metric: 'gitlab_auth_user_authenticated_total' },
          { legend: 'Unauthenticated', metric: 'gitlab_auth_user_unauthenticated_total' },
        ]
      ),
      signInMultiTimeSeries(
        'CAPTCHA', [
          { legend: 'Successful', metric: 'successful_login_captcha_total' },
          { legend: 'Failed', metric: 'failed_login_captcha_total' },
        ]
      ),
    ],
    startRow=1001,
    collapse=true
  );

{
  panels():: panels(),
}
