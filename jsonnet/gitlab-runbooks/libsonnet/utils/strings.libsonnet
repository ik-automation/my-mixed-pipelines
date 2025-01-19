local removeBlankLines(str) =
  std.strReplace(str, '\n\n', '\n');

local chomp(str) =
  if std.isString(str) then
    std.rstripChars(str, '\n')
  else
    std.assertEqual(str, { __assert__: 'str should be a string value' });

local indent(str, spaces) =
  std.strReplace(removeBlankLines(chomp(str)), '\n', '\n' + std.repeat(' ', spaces));

local unwrapText(str) =
  local lines = std.split(str, '\n');
  local linesTrimmed = std.map(function(l) std.rstripChars(l, ' \t'), lines);
  local linesJoined = std.foldl(
    function(memo, line)
      local memoLast = std.length(memo) - 1;
      local prevItem = memo[memoLast];
      if line == '' || prevItem == '' then
        memo + [line]
      else
        // Join onto previous line
        memo[:memoLast] + [prevItem + ' ' + line],
    linesTrimmed[1:],
    linesTrimmed[:1]
  );
  std.join('\n', linesJoined);

local capitalizeFirstLetter(str) =
  local chars = std.stringChars(str);
  if std.length(chars) == 0 then
    ''
  else
    std.asciiUpper(chars[0]) + std.join('', chars[1:]);

local splitOnChars(str, chars) =
  if std.length(chars) < 2 then
    std.split(str, chars)
  else
    local charArray = std.stringChars(chars);
    local first = charArray[0];
    local stringIntermediate =
      std.foldl(
        function(str, char) std.strReplace(str, char, first),
        charArray[1:],
        str
      );

    std.filter(
      function(f) f != '',
      std.split(stringIntermediate, first)
    );

// (very) partial implementation of URL encode
// aka, enough to get by
local defaultReplacements = [
  [' ', '+'],
  [':', '%3A'],
];
local urlEncode(string, replacements=defaultReplacements) =
  std.foldl(
    function(string, replacement) std.strReplace(string, replacement[0], replacement[1]),
    replacements,
    string
  );

// Composes a series of markdown paragraphs from a set of lines,
local markdownParagraphs(lines) =
  local cleaned = std.map(function(l) chomp(l), lines);
  local filtered = std.filter(function(l) l != '', cleaned);
  std.join('\n\n', filtered) + '\n';


local toCamelCase(str, splitChars='-_') =
  std.join(
    '',
    std.map(
      capitalizeFirstLetter,
      splitOnChars(str, '-_')
    )
  );

{
  removeBlankLines(str):: removeBlankLines(str),
  chomp(str):: chomp(str),
  indent(str, spaces):: indent(str, spaces),
  unwrapText(str):: unwrapText(str),

  /* Like split, but allows for multiple chars to split on */
  splitOnChars:: splitOnChars,

  /* Make the first letter of a string capital */
  capitalizeFirstLetter: capitalizeFirstLetter,

  // (very) partial implementation of URL encode
  // aka, enough to get by
  urlEncode: urlEncode,

  markdownParagraphs:: markdownParagraphs,

  // toCamelCase will convert a string to CamelCase, splitting the words on `splitChars`
  // by default `splitChars` is `_-`.
  // Examples:
  // this-is-a-string -> ThisIsAString
  // this_is_a_string -> ThisIsAString
  // this-is_a_string -> ThisIsAString
  toCamelCase: toCamelCase,
}
