import { ReviewReport } from './types.ts';

function escapeCell(value: string): string {
  return value.replace(/\|/g, '\\|').replace(/\r?\n/g, '<br>');
}

export function renderMarkdown(report: ReviewReport): string {
  const findings = report.findings ?? [];
  const nextSteps = report.next_steps ?? [];
  const notes = report.notes ?? [];

  const lines: string[] = [];
  lines.push(`# ${report.title || 'Agentic Run Report'}`);
  lines.push('');
  lines.push('| Field | Value |');
  lines.push('|---|---|');
  lines.push(`| Verdict | ${report.verdict} |`);
  lines.push(`| Findings | ${findings.length} |`);
  lines.push('');

  if (report.summary) {
    lines.push('## Summary');
    lines.push('');
    lines.push(report.summary);
    lines.push('');
  }

  lines.push('## Findings');
  lines.push('');
  if (findings.length > 0) {
    lines.push('| Severity | Title | Details | Recommendation |');
    lines.push('|---|---|---|---|');
    for (const finding of findings) {
      lines.push(
        `| ${escapeCell(finding.severity)} | ${escapeCell(finding.title)} | ${escapeCell(finding.details)} | ${escapeCell(finding.recommendation)} |`,
      );
    }
    lines.push('');
  } else {
    lines.push('No findings reported.');
    lines.push('');
  }

  lines.push('## Next steps');
  lines.push('');
  if (nextSteps.length > 0) {
    for (const step of nextSteps) {
      lines.push(`- ${step}`);
    }
  } else {
    lines.push('- None');
  }
  lines.push('');

  if (notes.length > 0) {
    lines.push('## Notes');
    lines.push('');
    for (const note of notes) {
      lines.push(`- ${note}`);
    }
    lines.push('');
  }

  return lines.join('\n');
}
