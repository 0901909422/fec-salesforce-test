$path = 'force-app/main/default/classes/FEC_CommonUltils.cls'
$content = Get-Content $path -Raw
$content = $content.TrimEnd()
$lastBrace = $content.LastIndexOf('}')
$content = $content.Substring(0, $lastBrace).TrimEnd()
Set-Content $path -Value $content -NoNewline
