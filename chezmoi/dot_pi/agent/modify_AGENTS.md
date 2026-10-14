{{/* chezmoi:template:line-endings=lf */}}
{{- /* chezmoi:modify-template */ -}}
{{- includeTemplate ".chezmoitemplates/agent-rules.md" (dict
    "current" .chezmoi.stdin
    "blocks" (list
        (includeTemplate ".chezmoitemplates/agent-token-efficiency.md" .)
        (includeTemplate ".chezmoitemplates/agent-file-search.md" .)
    )
) -}}
