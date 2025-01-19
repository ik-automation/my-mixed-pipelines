# Alerts

This is a small self-contained libsonnet library for processing alerts for GitLab's monitoring stack.

When generating alerts from jsonnet, pass the alert through this module to ensure that GitLab's
alerting conventions are followed.

```jsonnet
processAlertRule({
  alert: 'AlertOnThingsDown',
  expr: |||
    up < 0
  |||
})
```
