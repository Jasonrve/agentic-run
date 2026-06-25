# agentic-run

`agentic-run` is a reusable GitHub Action that sends a prompt to an OpenAI-compatible LLM, asks the model for a strict JSON report, renders a clean Markdown summary, and optionally upserts a single PR comment.

## What it does

- accepts a `prompt` and optional `context`
- calls any OpenAI-compatible LLM endpoint
- uses `openai/gpt-4o-mini` by default
- renders a Markdown report with:
  - verdict
  - summary
  - findings table
  - next steps
- upserts one stable PR comment instead of creating duplicates
- can fail the workflow when findings are present
- supports multiple context strategies:
  - `diff` — pass changed-file diff only
  - `full` — include full changed-file contents
  - `hybrid` — include diff plus file contents
  - `agentic` — start with diff/context, then let the model request more files

## Inputs

| Input | Required | Default | Purpose |
|---|---:|---|---|
| `prompt` | yes | — | Main instruction for the LLM |
| `context` | no | `` | Extra context appended to the prompt |
| `llm_base_url` | yes | — | OpenAI-compatible LLM base URL |
| `llm_api_key` | yes | — | OpenAI-compatible LLM API key |
| `model` | no | `openai/gpt-4o-mini` | Model to use |
| `pr_number` | no | `` | PR number to comment on |
| `post_comment` | no | `true` | Upsert the PR comment |
| `fail_on_findings` | no | `false` | Exit non-zero when findings exist |
| `comment_marker` | no | `<!-- agentic-run -->` | Stable marker for comment upsert |
| `dry_run` | no | `false` | Render output without posting a comment |
| `mock_response_file` | no | `` | Validation helper for local/CI dry runs |
| `context_mode` | no | `diff` | Context strategy (`diff`, `full`, `hybrid`, `agentic`) |
| `extra_context_paths` | no | `` | Comma or newline separated file paths to always include |
| `max_file_chars` | no | `12000` | Maximum characters to load per file |
| `max_follow_up_rounds` | no | `1` | Max extra rounds in agentic mode |

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
          github_token: ${{ github.token }}
          llm_base_url: ${{ secrets.LLM_BASE_URL }}
          llm_api_key: ${{ secrets.LLM_API_KEY }}
          context_mode: agentic
          extra_context_paths: |
            docs/governance-rules.md
          prompt: |
            Review the Terraform changes in this PR for governance and security issues.
            Return a concise report suitable for a PR comment.
          fail_on_findings: true
```

## Provider examples

`agentic-run` is provider-agnostic as long as the endpoint speaks the OpenAI chat-completions shape.

Examples:

- Bifrost: `https://bifrost.workside.win/v1`
- OpenRouter: `https://openrouter.ai/api/v1`
- Local gateways: any internal OpenAI-compatible proxy

## Local validation

The repo includes a dry-run-friendly validation path so the action can be checked without calling a live model provider.

- `npm test` exercises the TypeScript rendering and agentic follow-up flow
- `npm run build` bundles `dist/index.js`
- `.github/workflows/validate.yml` exercises the published action with a fixture

## LLM contract

The action expects the provider to behave like an OpenAI-compatible chat completions API.
It currently calls:

```text
POST {llm_base_url}/chat/completions
```

If your provider uses a different path, adjust the action or point `llm_base_url` at a compatible gateway.
