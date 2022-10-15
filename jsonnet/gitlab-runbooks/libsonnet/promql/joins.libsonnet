local strings = import 'utils/strings.libsonnet';

local join(operator, expressions, wrapTerms=true) =
  if std.length(expressions) == 0 then
    ''
  else
    if wrapTerms then
      local termsWrapped = std.map(
        function(expression)
          |||
            (
              %(expression)s
            )
          ||| % {
            expression: strings.indent(strings.chomp(expression), 2),
          },
        expressions
      );
      std.join(operator + '\n', termsWrapped)
    else
      std.join('\n' + operator + '\n', std.map(strings.chomp, expressions)) + '\n';

{
  /* join a set of expressions */
  join:: join,
}
