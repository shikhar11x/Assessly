# Sandbox verification for the execution service. Prints PASS/FAIL per check.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$token = ((Get-Content "$root\docker\.env") | Where-Object { $_ -like 'EXECUTOR_TOKEN=*' }) -replace '^EXECUTOR_TOKEN=', ''
$url = 'http://127.0.0.1:4000'
$script:pass = 0
$script:fail = 0

function Run($code, $stdin = '', $timeout = 2000, $tok = $token) {
  $body = @{ code = $code; input = $stdin; timeoutMs = $timeout } | ConvertTo-Json
  Invoke-RestMethod -Method Post -Uri "$url/execute" -Headers @{ 'X-Executor-Token' = $tok } -ContentType 'application/json' -Body $body -TimeoutSec 20
}
function Check($name, $ok, $detail = '') {
  if ($ok) { Write-Output "PASS  $name"; $script:pass++ } else { Write-Output "FAIL  $name  $detail"; $script:fail++ }
}

Write-Output "Execution service sandbox tests - $(Get-Date -Format s)"

$r = Run 'print(int(input()) + 1)' "41`n"
Check 'runs normal code with stdin' ($r.status -eq 'ok' -and $r.stdout.Trim() -eq '42') $r.status

$r = Run 'while True: pass' '' 1000
Check 'kills an infinite loop (timeout)' ($r.status -eq 'timeout' -and $r.durationMs -lt 4000) "$($r.status) $($r.durationMs)ms"

$r = Run '1/0'
Check 'reports runtime errors' ($r.status -eq 'runtime_error' -and $r.stderr -match 'ZeroDivisionError') $r.status

$r = Run "x = 'a' * (1024*1024*1024)`nprint(len(x))" '' 3000
Check 'stops a memory bomb (1 GiB allocation)' ($r.status -ne 'ok' -and $r.stderr -match 'MemoryError') "$($r.status) $($r.stderr)"

$r = Run "import os`nwhile True:`n    os.fork()" '' 2000
$health = Invoke-RestMethod "$url/health" -TimeoutSec 10
Check 'survives a fork bomb and stays healthy' (($r.status -in @('timeout', 'runtime_error')) -and $health.status -eq 'ok') $r.status

$r = Run 'import os; print(os.getuid())'
Check 'student code is not root' ($r.status -eq 'ok' -and $r.stdout.Trim() -ne '0') $r.stdout

$r = Run "open('/tmp/x', 'w').write('x')"
Check 'cannot write files' ($r.status -eq 'runtime_error') "$($r.status) $($r.stderr)"

$r = Run "print(open('/proc/1/environ').read())"
Check 'cannot read the server environment (token safe)' ($r.status -eq 'runtime_error' -and -not ($r.stdout -match [regex]::Escape($token))) $r.status

$r = Run "while True: print('x' * 1000)" '' 2000
Check 'caps output flooding' ($r.status -in @('output_limit', 'timeout')) $r.status

try { Run 'print(1)' '' 1000 'wrong-token' | Out-Null; Check 'rejects a wrong token' $false 'no error returned' }
catch { Check 'rejects a wrong token (401)' ($_.Exception.Response.StatusCode.value__ -eq 401) }

$r = Run "import socket`ntry:`n    socket.create_connection(('1.1.1.1', 53), 2)`n    print('CONNECTED')`nexcept Exception as e:`n    print('BLOCKED', type(e).__name__)" '' 4000
Write-Output "INFO  outbound network from sandbox: $($r.stdout.Trim())  (known dev limitation; blocked by NetworkPolicy in Kubernetes)"

Write-Output "Result: $script:pass passed, $script:fail failed"
if ($script:fail -gt 0) { exit 1 }
