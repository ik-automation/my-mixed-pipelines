local misc = import 'utils/misc.libsonnet';
local strings = import 'utils/strings.libsonnet';

local generateRow(row) =
  '| ' +
  std.join(
    ' | ',
    std.map(function(cell) strings.urlEncode(cell, [['|', '\\|']]), row)
  ) +
  ' |';

// Poor-man table generation
local generateTable(headers, rows) =
  assert misc.all(function(row) std.length(headers) == std.length(row), rows) :
         'Length of headers and length of data mismatched!';

  std.join(
    '\n ',
    [generateRow(headers)] +
    [generateRow(std.repeat(['---'], std.length(headers)))] +
    std.map(generateRow, rows)
  );


{
  generateTable: generateTable,
}
