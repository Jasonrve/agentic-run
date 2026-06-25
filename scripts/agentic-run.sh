#!/usr/bin/env bash
set -euo pipefail

require() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "missing required env: $name" >&2
    exit 1
  fi
}

require INPUT_PROMPT
require INPUT_BIFROST_BASE_URL
require BIFROST
require INPUT_MODEL

trim_code_fence() {
  local text="$1"
  text="${text#\`\`\`json}"
  text="${text#\`\`\`}"
  text="${text%\`\`\`}"
  printf '%s' "$text"
}

build_request() {
  jq -n \
    --arg model "$INPUT_MODEL" \
    --arg system "You are a disciplined review and reporting assistant. Return ONLY valid JSON with the following shape: {\"title\": string, \"summary\": string, \"verdict\": \"pass\"|\"warn\"|\"fail\", \"findings\": [{\"severity\": \"critical\"|\"high\"|\"medium\"|\"low\", \"title\": string, \"details\": string, \"recommendation\": string}], \"next_steps\": [string], \"notes\": [string] }. Keep the content concise, specific, and suitable for a GitHub PR comment. If there are no issues, set verdict to pass and findings to an empty array." \
    --arg prompt "$INPUT_PROMPT" \
    --arg context "$INPUT_CONTEXT" \
    '{model:$model, messages:[{role:"system", content:$system}, {role:"user", content:($prompt + (if $context != "" then "\n\nContext:\n" + $context else "" end))}], temperature:0.2}'
}

extract_content() {
  local raw="$1"
  local content
  content="$(jq -r '.choices[0].message.content // empty' <<<"$raw")"
  if [[ -z "$content" ]]; then
    echo "Bifrost response did not include message content" >&2
    echo "$raw" >&2
    exit 1
  fi
  trim_code_fence "$content"
}

render_markdown() {
  local json="$1"
  local title summary verdict finding_count
  title="$(jq -r '.title // "Agentic Run Report"' <<<"$json")"
  summary="$(jq -r '.summary // ""' <<<"$json")"
  verdict="$(jq -r '.verdict // "warn"' <<<"$json")"
  finding_count="$(jq -r '(.findings // []) | length' <<<"$json")"

  {
    printf '# %s\n\n' "$title"
    printf '| Field | Value |\n|---|---|\n'
    printf '| Verdict | %s |\n' "$verdict"
    printf '| Findings | %s |\n\n' "$finding_count"

    if [[ -n "$summary" ]]; then
      printf '## Summary\n\n%s\n\n' "$summary"
    fi

    if [[ "$finding_count" -gt 0 ]]; then
      printf '## Findings\n\n'
      printf '| Severity | Title | Details | Recommendation |\n|---|---|---|---|\n'
      jq -r '.findings[] | [(.severity // "medium"), (.title // ""), (.details // ""), (.recommendation // "")] | @tsv' <<<"$json" |
        while IFS=$'\t' read -r severity finding_title details recommendation; do
          severity="${severity//|/\\|}"
          finding_title="${finding_title//|/\\|}"
          details="${details//|/\\|}"
          recommendation="${recommendation//|/\\|}"
          printf '| %s | %s | %s | %s |\n' "$severity" "$finding_title" "$details" "$recommendation"
        done
      printf '\n'
    else
      printf '## Findings\n\nNo findings reported.\n\n'
    fi

    printf '## Next steps\n\n'
    if jq -e '(.next_steps // []) | length > 0' <<<"$json" >/dev/null; then
      jq -r '.next_steps[]' <<<"$json" | sed 's/^/- /'
    else
      printf '- None\n'
    fi
    printf '\n'

    if jq -e '(.notes // []) | length > 0' <<<"$json" >/dev/null; then
      printf '## Notes\n\n'
      jq -r '.notes[]' <<<"$json" | sed 's/^/- /'
      printf '\n'
    fi
  } | tee /tmp/agentic-run-comment.md
}

response_json=""
if [[ -n "${INPUT_MOCK_RESPONSE_FILE:-}" ]]; then
  if [[ ! -f "$INPUT_MOCK_RESPONSE_FILE" ]]; then
    echo "mock response file not found: $INPUT_MOCK_RESPONSE_FILE" >&2
    exit 1
  fi
  response_json="$(<"$INPUT_MOCK_RESPONSE_FILE")"
else
  request_payload="$(build_request)"
  auth_prefix="Authorization:"
  auth_header="$auth_prefix Bearer $BIFROST"
  response_json="$(curl -sS --fail-with-body \
    "$INPUT_BIFROST_BASE_URL/chat/completions" \
    -H "$auth_header" \
    -H 'Content-Type: application/json' \
    --data-binary "$request_payload")"
fi

content="$(extract_content "$response_json")"

# Allow the model to return either strict JSON or fenced JSON.
if ! json_payload="$(jq -c '.' <<<"$content" 2>/dev/null)"; then
  content="$(trim_code_fence "$content")"
  json_payload="$(jq -c '.' <<<"$content")"
fi

comment_body="$(render_markdown "$json_payload")"
verdict="$(jq -r '.verdict // "warn"' <<<"$json_payload")"
finding_count="$(jq -r '(.findings // []) | length' <<<"$json_payload")"

{
  echo "verdict=$verdict"
  echo "finding_count=$finding_count"
  echo 'comment_body<<EOF'
  cat /tmp/agentic-run-comment.md
  echo EOF
} >> "$GITHUB_OUTPUT"

if [[ "${INPUT_FAIL_ON_FINDINGS:-false}" == "true" ]]; then
  if [[ "$verdict" != "pass" || "$finding_count" != "0" ]]; then
    echo "agentic-run generated findings and fail_on_findings=true" >&2
    exit 1
  fi
fi
