# Inhibit Rules

This is a collection of common dependencies through our application, for example a lot of services will depends on a `patroni` cluster.

## Usage

```jsonnet
local dependOnPatroni = import 'inhibit-rules/depend_on_patroni.libsonnet';

metricsCatalog.serviceDefinition({
    type: 'web',

    serviceLevelIndicators: {
        workhorse: {
            dependsOn: dependOnPatroni.sql_components,
        },
    },
})
```
