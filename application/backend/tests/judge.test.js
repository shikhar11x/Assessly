'use strict';

const { normalize, outputsMatch, judge, awardMarks } = require('../src/judge');

describe('output comparison', () => {
  it('ignores CRLF, trailing spaces and trailing blank lines', () => {
    expect(outputsMatch('5  \r\n6\r\n\r\n', '5\n6')).toBe(true);
    expect(normalize(null)).toBe('');
  });
  it('detects a different output', () => {
    expect(outputsMatch('5', '6')).toBe(false);
  });
});

describe('judge', () => {
  const cases = [
    { input: '1', expected_output: '2', is_sample: true },
    { input: '2', expected_output: '3', is_sample: false },
  ];

  it('passes every case when the output matches', async () => {
    const runner = async ({ input }) => ({ status: 'ok', stdout: `${Number(input) + 1}\n`, stderr: '' });
    const r = await judge({ code: 'x', cases, runner });
    expect(r).toMatchObject({ passed: 2, total: 2 });
  });

  it('marks wrong answers and hides hidden-case details', async () => {
    const runner = async () => ({ status: 'ok', stdout: '0', stderr: '' });
    const r = await judge({ code: 'x', cases, runner });
    expect(r.passed).toBe(0);
    expect(r.results[0].verdict).toBe('wrong_answer');
    expect(r.results[0].expectedOutput).toBe('2'); // sample case is visible
    expect(r.results[1].expectedOutput).toBeUndefined(); // hidden case is not
    expect(r.results[1].actual).toBeUndefined();
  });

  it('turns timeouts and runtime errors into failed verdicts', async () => {
    const t = await judge({ code: 'x', cases, runner: async () => ({ status: 'timeout', stdout: '', stderr: '' }) });
    expect(t.results[0]).toMatchObject({ passed: false, verdict: 'timeout' });
    const e = await judge({ code: 'x', cases, runner: async () => ({ status: 'runtime_error', stdout: '', stderr: 'boom' }) });
    expect(e.results[0].verdict).toBe('runtime_error');
  });

  it('propagates executor failures to the caller', async () => {
    const runner = async () => { throw new Error('down'); };
    await expect(judge({ code: 'x', cases, runner })).rejects.toThrow('down');
  });
});

describe('awardMarks', () => {
  it('gives proportional partial credit', () => {
    expect(awardMarks(2, 3, 2)).toBe(1.33);
    expect(awardMarks(3, 3, 2)).toBe(2);
  });
  it('returns 0 when there are no cases', () => {
    expect(awardMarks(0, 0, 2)).toBe(0);
  });
});
