'use strict';

const { cell, toCsv } = require('../src/csv_export');

describe('csv export', () => {
  it('quotes commas, quotes and newlines', () => {
    expect(cell('a,b')).toBe('"a,b"');
    expect(cell('say "hi"')).toBe('"say ""hi"""');
    expect(cell('x\ny')).toBe('"x\ny"');
  });

  it('neutralises spreadsheet formulas', () => {
    expect(cell('=1+1')).toBe("'=1+1");
    expect(cell('@SUM(A1)')).toBe("'@SUM(A1)");
  });

  it('builds header and rows, with empty cells for null', () => {
    expect(toCsv(['a', 'b'], [[1, null], ['x', 2]])).toBe('a,b\n1,\nx,2\n');
  });
});
