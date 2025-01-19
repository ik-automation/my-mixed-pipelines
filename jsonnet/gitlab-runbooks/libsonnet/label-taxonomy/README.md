# Label Taxonomies

GitLab uses a set of standardized labels to allow metrics and logs to be aggregated in a standard way. Matching labels over different exporters and metrics allows the simplification of visualization, analysis and alerting logic across GitLab observability data.

However, for a variety of reasons, the taxonomies of labels used in different GitLab instances differs. For instance, GET instances do not need an `environment`, `shard` or `stage` label, while these are important for GitLab.com.

The `label-taxonomy` library allows different label to be used in different GET environments, while also allowing certain labels to be omitted from environments.

### Taxonomy Classification

The following label types of classified in the label taxonomy.

| **Category**        | **Description**                                                                                             | **GitLab.com Example** |
| ------------------- | ----------------------------------------------------------------------------------------------------------- | ---------------------- |
| `environmentThanos` | The environment selector label used for Thanos                                                              | `env="gprd"`           |
| `environment`       | The environment selector used for Prometheus                                                                | `environment="gprd"`   |
| `tier`              | The service tier (`sv`, `db` `stor` etc)                                                                    | `tier="stor"`          |
| `service`           | The service identifier (mandatory)                                                                          | `type="gitaly"`        |
| `stage`             | Used for identifying staggered deployments within a single environment (`main`, `cny` etc)                  | `stage="cny"`          |
| `shard`             | An service bulkhead, used to isolating subcomponents of a service against saturation in other subcomponents | `shard="maquee"`       |
| `node`              | The label used to identify a VM instance                                                                    | `fqdn="file-01..."`    |

## Configuring the Label Taxonomy

The label taxonomy should be defined in the [`gitlab-metrics-config.libsonnet`](../../metrics-catalog/gitlab-metrics-config.libsonnet) configuration file.

This maps a label key to an actual string label value, or `null` if the label is not used in a specific environment.

```jsonnet
  labelTaxonomy:: labelSet.makeLabelSet({
    environmentThanos: null,  // No thanos
    environment: null,  // Only one environment
    tier: null,  // No tiers
    service: 'type',
    stage: null,  // No stages
    shard: null,  // No shards
    node: 'node',
  }),
}
```

(Note: for all results in examples are based on the configuration posted above).

## Using the API

### Labelsets

Label sets are internally defined as a using a [bitset](https://en.wikipedia.org/wiki/Bit_array). The set of all labels is defined in `labelTaxonomy.labels`.

Labelsets can be created using the `|` operator, for example:

```jsonnet
local requiredLabelSet = labelTaxonomy.labels.environmentThanos | labelTaxonomy.labels.environment | labelTaxonomy.labels.node;
```

Labelsets can be joined together using the `|` operator.

```jsonnet
// Union of all labels in both sets
local labelSet3 = labelSet1 | labelSet2;
```

Other operations (subtraction, intersection etc) can similarly be done using bitwise arithmetic.

### `labelTaxonomy.labelTaxonomy(labelSet) --> [labels]`

The `labelTaxonomy(labelSet)` method will return the actual labels for a given labelSet. Any labels not defined for a given environment will be omitted.

```jsonnet
local labels = labelTaxonomy.labels;
labelTaxonomy.labelTaxonomy(l.environmentThanos | l.environment | l.service | l.node) => ['type', 'node`]
```

### `labelTaxonomy.labelTaxonomySerialized(labelSet) --> "labels"`

Similar to `labelTaxonomy(labelSet)`, except this will return a string, suitable for use in PromQL.

```jsonnet
local labels = labelTaxonomy.labels;
labelTaxonomy.labelTaxonomy(l.environmentThanos | l.environment | l.service | l.node) => 'type,node'
```

### `getLabelFor(label, default='')`

Returns the actual label string value for a given label.

```jsonnet
labelTaxonomy.getLabelFor(labelTaxonomy.labels.stage, default="") ==> ''
```
