{{- $begin := "<!-- BEGIN chezmoi-managed rules -->" -}}
{{- $end := "<!-- END chezmoi-managed rules -->" -}}
{{- $external := replace "\r\n" "\n" (trimPrefix "\ufeff" .current) -}}
{{- if or (contains $begin $external) (contains $end $external) -}}
{{- $before := splitList $begin $external -}}
{{- if or (ne (len $before) 2) (ne (len (splitList $end $external)) 2) -}}
{{- fail "AGENTS.md must contain exactly one complete chezmoi-managed rules block" -}}
{{- end -}}
{{- $after := splitList $end (index $before 1) -}}
{{- if ne (len $after) 2 -}}
{{- fail "AGENTS.md chezmoi-managed rules markers are out of order" -}}
{{- end -}}
{{- /* Keep text outside the managed block, moving any prefix after our rules. */ -}}
{{- $external = printf "%s\n\n%s" (trimAll "\n" (index $before 0)) (trimAll "\n" (index $after 1)) -}}
{{- else -}}
{{- /* Migrate previous unmarked rules without taking ownership of plugin content. */ -}}
{{- range .blocks -}}
{{- $external = replace (trimAll "\n" .) "" $external -}}
{{- end -}}
{{- end -}}
{{- $blocks := list -}}
{{- range .blocks -}}
{{- $blocks = append $blocks (trimAll "\n" .) -}}
{{- end -}}
{{- printf "%s\n%s\n%s\n" $begin (join "\n\n" $blocks) $end -}}
{{- $external = trimAll "\n" $external -}}
{{- if ne $external "" -}}
{{- printf "\n%s\n" $external -}}
{{- end -}}
