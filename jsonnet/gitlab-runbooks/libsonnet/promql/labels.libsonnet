local strings = import 'utils/strings.libsonnet';

{
  /**
   * Add a fixed label to a promql query for use in visualisations
   * This is handy when plotting 2 different metrics in the same visualisation.
   */
  addStaticLabel(labelName, labelValue, query)::
    |||
      label_replace(
        %(query)s,
        '%(labelName)s', '%(labelValue)s' , '', ''
      )
    ||| % {
      query: strings.indent(query, 2),
      labelName: labelName,
      labelValue: labelValue,
    },
}
