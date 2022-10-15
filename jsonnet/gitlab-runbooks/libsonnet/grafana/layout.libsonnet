local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';

local generateColumnOffsets(columnWidths) =
  std.foldl(function(columnOffsets, width) columnOffsets + [width + columnOffsets[std.length(columnOffsets) - 1]], columnWidths, [0]);

local generateRowOffsets(cellHeights) =
  std.foldl(function(rowOffsets, cellHeight) rowOffsets + [cellHeight + rowOffsets[std.length(rowOffsets) - 1]], cellHeights, [0]);

local generateDropOffsets(cellHeights, rowOffsets) =
  local totalHeight = std.foldl(function(sum, cellHeight) sum + cellHeight, cellHeights, 0);
  [
    totalHeight - rowOffset
    for rowOffset in rowOffsets
  ];

local titleRowWithPanels(title, panels, collapse, startRow) =
  local titleRow = grafana.row.new(title=title, collapse=collapse) { gridPos: { x: 0, y: startRow, w: 24, h: 1 } };
  if collapse then
    [titleRow.addPanels(panels)]
  else
    [
      titleRow,
    ] + panels;

{
  // Returns a grid layout with `cols` columns
  // panels should be an array of panels
  grid(panels, cols=2, rowHeight=10, startRow=0)::
    std.mapWithIndex(
      function(index, panel)
        panel {
          gridPos: {
            x: ((24 / cols) * index) % 24,
            y: std.floor(((24 / cols) * index) / 24) * rowHeight + startRow,
            w: 24 / cols,
            h: rowHeight,
          },
        },
      panels
    ),

  // Layout all the panels in a single row
  singleRow(panels, rowHeight=10, startRow=0)::
    local cols = std.length(panels);
    self.grid(panels, cols=cols, rowHeight=rowHeight, startRow=startRow),

  rowGrid(rowTitle, panels, startRow, rowHeight=10, collapse=false)::
    local panelRow = self.singleRow(panels, rowHeight=rowHeight, startRow=(startRow + 1));
    titleRowWithPanels(rowTitle, panelRow, collapse, startRow),

  titleRowWithPanels:: titleRowWithPanels,

  // Rows -> array of arrays. Each outer array is a row.
  rows(rowsOfPanels, rowHeight=10, startRow=0)::
    std.flattenArrays(
      std.mapWithIndex(
        function(index, panels)
          if std.isArray(panels) then
            self.singleRow(panels, rowHeight=rowHeight, startRow=index * rowHeight + startRow)
          else
            local panel = panels;
            [
              panel {
                gridPos: {
                  x: 0,
                  y: index * rowHeight + startRow,
                  w: 24,
                  h: rowHeight,
                },
              },
            ],
        rowsOfPanels
      )
    ),

  columnGrid(rowsOfPanels, columnWidths, rowHeight=10, startRow=0)::
    local columnOffsets = generateColumnOffsets(columnWidths);

    std.flattenArrays(
      std.mapWithIndex(
        function(rowIndex, rowOfPanels)
          std.mapWithIndex(
            function(colIndex, panel)
              panel {
                gridPos: {
                  x: columnOffsets[colIndex],
                  y: rowIndex * rowHeight + startRow,
                  w: columnWidths[colIndex],
                  h: rowHeight,
                },
              },
            rowOfPanels
          ),
        rowsOfPanels
      )
    ),

  // Each column contains an array of cells, stacked vertically
  // the heights of each cell are defined by cellHeights
  splitColumnGrid(columnsOfPanels, cellHeights, startRow, columnWidths=null, title='', collapse=false)::
    local getXOffsetForColumn =
      if columnWidths == null then
        local colWidth = std.floor(24 / std.length(columnsOfPanels));
        function(colIndex) colWidth * colIndex
      else
        function(colIndex)
          std.foldr(
            function(memo, width) memo + width,
            columnWidths[0:colIndex:1],
            0
          );

    local getWidthForColumn =
      if columnWidths == null then
        local colWidth = std.floor(24 / std.length(columnsOfPanels));
        function(colIndex) colWidth
      else
        function(colIndex) columnWidths[colIndex];

    local rowOffsets = generateRowOffsets(cellHeights);
    local dropOffsets = generateDropOffsets(cellHeights, rowOffsets);

    local panels = std.prune(
      std.flattenArrays(
        std.mapWithIndex(
          function(colIndex, columnOfPanels)
            if std.isArray(columnOfPanels) then
              std.mapWithIndex(
                function(cellIndex, cell)
                  if cell == null then
                    null
                  else
                    local lastRowInColumn = cellIndex == (std.length(columnOfPanels) - 1);

                    // The height of the last cell will extend to the bottom
                    local height = if !lastRowInColumn then
                      cellHeights[cellIndex]
                    else
                      dropOffsets[cellIndex];

                    local gridPos = {
                      x: getXOffsetForColumn(colIndex),
                      y: rowOffsets[cellIndex] + startRow,
                      w: getWidthForColumn(colIndex),
                      h: height,
                    };

                    cell {
                      gridPos: gridPos,
                    },
                columnOfPanels
              )
            else
              std.assertEqual('', { __assert__: 'splitColumnGrid: column %d contains a %s. It should contain an columnar array of panels' % [colIndex, std.type(columnOfPanels)] }),
          columnsOfPanels
        )
      )
    );

    if title != '' then
      titleRowWithPanels(title, panels, collapse, startRow)
    else panels,
}
