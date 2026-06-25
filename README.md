# agentic-run

`agentic-run` is a reusable GitHub Action that sends a prompt to Bifrost, asks the model for a strict JSON report, renders a clean Markdown summary, and optionally upserts a single PR comment.

## What it does

- accepts a `prompt` and optional `context`
- calls the Bifrost OpenAI-compatible endpoint
- uses `openai/gpt-4o-mini` by default
- renders a Markdown report with:
  - verdict
  - summary
  - findings table
  - next steps
- upserts one stable PR comment instead of creating duplicates
- can fail the workflow when findings are present

## Inputs

| Input | Required | Default | Purpose |
|---|---:|---|---|
| `prompt` | yes | — | Main instruction for the LLM |
| `context` | no | `` | Extra context appended to the prompt |
| `bifrost_base_url` | no | `https://bifrost.workside.win/v1` | Bifrost OpenAI-compatible base URL |
| `bifrost_api_key` | yes | — | Bifrost API key |
| `model` | no | `openai/gpt-4o-mini` | Model to use |
| `pr_number` | no | `` | PR number to comment on |
| `post_comment` | no | `true` | Upsert the PR comment |
| `fail_on_findings` | no | `false` | Exit non-zero when findings exist |
| `comment_marker` | no | `<!-- agentic-run -->` | Stable marker for comment upsert |
| `dry_run` | no | `false` | Render output without posting a comment |
| `mock_response_file` | no | `` | Validation helper for local/CI dry runs |

## Example usage

```yaml
name: Terraform security review

on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]

permissions:
  contents: read
  pull-requests: write
  issues: write

jobs:
  security-review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run agentic review
        uses: Jasonrve/agentic-run@v1
        with:
          bifrost_api_key: ${{ secrets.BIFROST_API_KEY }}
          prompt: |
            Review the Terraform changes in this PR for governance and security issues.
            Return a concise report suitable for a PR comment.
          context: |
            Repo policy: missing owner/cost_center/data_classification/service tags are high severity.
            If the report finds issues, explain them clearly and recommend fixes.
          fail_on_findings: true
```

## Local validation

The repo includes a dry-run-friendly validation path so the action can be checked without calling Bifrost.

- `scripts/agentic-run.sh` supports `mock_response_file`
- `.github/workflows/validate.yml` exercises the composite action with a fixture

## Bifrost contract

The action expects Bifrost to behave like an OpenAI-compatible chat completions API.
It currently calls:

```text
POST {bifrost_base_url}/chat/completions
```

If your Bifrost deployment uses a different path, adjust the action or override `bifrost_base_url` in the consuming workflow.
