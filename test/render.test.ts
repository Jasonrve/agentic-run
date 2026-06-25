import { test } from 'node:test';
import assert from 'node:assert/strict';
import { renderMarkdown } from '../src/render.ts';

test('renderMarkdown formats a finding table and next steps', () => {
  const output = renderMarkdown({
    title: 'Terraform Governance Review',
    summary: 'Missing owner tag on a security group.',
    verdict: 'warn',
    findings: [
      {
        severity: 'high',
        title: 'Missing owner tag',
        details: 'The resource is missing owner metadata.',
        recommendation: 'Add an owner tag before merging.',
      },
    ],
    next_steps: ['Add missing tags', 'Re-run the workflow'],
    notes: ['Focused on changed Terraform files.'],
  });

  assert.match(output, /# Terraform Governance Review/);
  assert.match(output, /\| Verdict \| warn \|/);
  assert.match(output, /\| high \| Missing owner tag \|/);
  assert.match(output, /- Add missing tags/);
  assert.match(output, /## Notes/);
});
