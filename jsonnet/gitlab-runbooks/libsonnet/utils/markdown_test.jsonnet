local markdown = import './markdown.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

// For some reasons, the generated table contains training whitespace each
// line, it's harmless in markdown, but troublesome for testing
local split(str) =
  std.map(function(line) std.stripChars(line, ' '), std.split(str, '\n'));

test.suite({
  test1: {
    actual: split(markdown.generateTable(['Header A'], [['Hello']])),
    expect: [
      '| Header A |',
      '| --- |',
      '| Hello |',
    ],
  },
  test2: {
    actual: split(markdown.generateTable(
      ['Header A', 'Header B', ''],
      [
        ['Cell A', 'Cell B', 'Cell C'],
        ['Cell D', '', 'Cell E'],
        ['', '', 'Cell F'],
        ['', '', ''],
        ['Cell G', 'Cell H', 'Cell I'],
      ]
    )),
    expect:
      [
        '| Header A | Header B |  |',
        '| --- | --- | --- |',
        '| Cell A | Cell B | Cell C |',
        '| Cell D |  | Cell E |',
        '|  |  | Cell F |',
        '|  |  |  |',
        '| Cell G | Cell H | Cell I |',
      ],
  },
})
