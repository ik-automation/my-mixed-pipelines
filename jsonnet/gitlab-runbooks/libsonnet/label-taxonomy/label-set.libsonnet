local labels = (import './labels.libsonnet');

{
  makeLabelSet(hash)::
    std.foldl(
      function(memo, labelName)
        local label = labels[labelName];
        memo { ['' + label]: hash[labelName] },
      std.objectFields(labels),
      {}
    ),
}
