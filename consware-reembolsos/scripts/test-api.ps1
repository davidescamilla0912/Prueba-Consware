<#
  Matriz de pruebas T01-T16 del documento Consware_Guia_Tecnica (seccion 12).
  Uso:  powershell -ExecutionPolicy Bypass -File scripts\test-api.ps1
  Requiere: API ejecutandose en http://localhost:5000
  Devuelve codigo de salida != 0 si alguna prueba falla.
#>
param(
    [string]$BaseUrl = "http://localhost:5000/api/reimbursements",
    [string]$Employee = "Empleado Demo"
)

$ErrorActionPreference = "Stop"
$results = @()

function Invoke-Api {
    param([string]$Method, [string]$Url, [object]$Body)
    $params = @{ Method = $Method; Uri = $Url; ContentType = "application/json" }
    if ($null -ne $Body) { $params.Body = ($Body | ConvertTo-Json -Compress) }

    $status = 0; $text = ""
    try {
        $resp = Invoke-WebRequest @params -UseBasicParsing
        $status = [int]$resp.StatusCode
        $text = $resp.Content
    } catch {
        $response = $_.Exception.Response
        if ($null -eq $response) { return @{ Status = 0; Obj = $null; Raw = $_.Exception.Message } }
        $status = [int]$response.StatusCode
        try {
            $reader = New-Object IO.StreamReader($response.GetResponseStream())
            $text = $reader.ReadToEnd()
        } catch { $text = "" }
    }

    $obj = $null
    if ($text) { try { $obj = $text | ConvertFrom-Json } catch { $obj = $null } }
    return @{ Status = $status; Obj = $obj; Raw = $text }
}

function Add-Result {
    param([string]$Id, [bool]$Ok, [string]$Detail)
    $script:results += [pscustomobject]@{ Prueba = $Id; Resultado = $(if ($ok) { "PASS" } else { "FAIL" }); Detalle = $Detail }
}

function New-Request {
    param([double]$Amount, [string]$Category = "Transporte", [string]$Description = "Prueba automatizada", [string]$Name = $Employee)
    return @{ employeeName = $Name; amount = $Amount; category = $Category; description = $Description }
}

$employeeUrl = [uri]::EscapeDataString($Employee)

# --- Creacion -------------------------------------------------------------
$r = Invoke-Api POST $BaseUrl (New-Request 100000)
Add-Result "T01" ($r.Status -eq 201 -and $r.Obj.status -eq "Approved") "monto 100000 -> HTTP $($r.Status), estado $($r.Obj.status)"

$r = Invoke-Api POST $BaseUrl (New-Request 500000)
Add-Result "T02" ($r.Status -eq 201 -and $r.Obj.status -eq "Approved") "monto 500000 (limite exacto) -> HTTP $($r.Status), estado $($r.Obj.status)"

$r = Invoke-Api POST $BaseUrl (New-Request 500001)
Add-Result "T03" ($r.Status -eq 201 -and $r.Obj.status -eq "Pending") "monto 500001 -> HTTP $($r.Status), estado $($r.Obj.status)"
$pendingId = $r.Obj.id

$before = (Invoke-Api GET $BaseUrl).Obj.Count

$r = Invoke-Api POST $BaseUrl (New-Request 0)
$after = (Invoke-Api GET $BaseUrl).Obj.Count
Add-Result "T04" ($r.Status -eq 400 -and $before -eq $after) "monto 0 -> HTTP $($r.Status), no se guardo (registros $before -> $after)"

$r = Invoke-Api POST $BaseUrl (New-Request -1)
Add-Result "T05" ($r.Status -eq 400 -and $before -eq $after) "monto -1 -> HTTP $($r.Status), no se guardo"

$r = Invoke-Api POST $BaseUrl (New-Request 150000 "Transporte" "   ")
Add-Result "T06" ($r.Status -eq 400 -and $before -eq $after) "descripcion '   ' -> HTTP $($r.Status), no se guardo"

$r = Invoke-Api POST $BaseUrl (New-Request 150000 "   " "Descripcion valida")
Add-Result "T07" ($r.Status -eq 400 -and $before -eq $after) "categoria vacia -> HTTP $($r.Status), no se guardo"

$r = Invoke-Api POST $BaseUrl (@{ employeeName = $Employee; amount = 150000; category = ""; description = "x" })
Add-Result "T07b" ($r.Status -eq 400) "categoria '' -> HTTP $($r.Status)"

# --- Consultas ------------------------------------------------------------
$r = Invoke-Api GET "$BaseUrl/999999"
Add-Result "T08" ($r.Status -eq 404) "GET id inexistente -> HTTP $($r.Status)"

$r = Invoke-Api GET "$BaseUrl`?status=Pending"
$allPending = ($r.Status -eq 200) -and (@($r.Obj | Where-Object { $_.status -ne "Pending" }).Count -eq 0) -and (@($r.Obj).Count -gt 0)
Add-Result "T09" $allPending "GET ?status=Pending -> HTTP $($r.Status), $(@($r.Obj).Count) registros, todos Pending: $($allPending)"

$r = Invoke-Api GET "$BaseUrl`?employeeName=$employeeUrl"
$onlyEmployee = ($r.Status -eq 200) -and (@($r.Obj | Where-Object { $_.employeeName -ne $Employee }).Count -eq 0)
Add-Result "T10" $onlyEmployee "GET ?employeeName=$Employee -> HTTP $($r.Status), $(@($r.Obj).count) registros"

$r = Invoke-Api GET "$BaseUrl`?status=Pending&employeeName=$employeeUrl"
$intersect = ($r.Status -eq 200) -and (@($r.Obj | Where-Object { $_.status -ne "Pending" -or $_.employeeName -ne $Employee }).Count -eq 0)
Add-Result "T11" $intersect "GET filtros combinados -> HTTP $($r.Status), $(@($r.Obj).Count) registros"

$r = Invoke-Api GET "$BaseUrl`?status=Gibberish"
Add-Result "T11b" ($r.Status -eq 400) "GET estado desconocido -> HTTP $($r.Status)"

# --- Decisiones -----------------------------------------------------------
$r = Invoke-Api PATCH "$BaseUrl/$pendingId/approve" $null
Add-Result "T12" ($r.Status -eq 200 -and $r.Obj.status -eq "Approved") "PATCH approve pendiente #$pendingId -> HTTP $($r.Status), estado $($r.Obj.status)"

$r = Invoke-Api POST $BaseUrl (New-Request 750000 "Alimentacion" "Almuerzo con cliente")
$toReject = $r.Obj.id
$r = Invoke-Api PATCH "$BaseUrl/$toReject/reject" @{ reason = "No cumple la politica de gastos." }
Add-Result "T13" ($r.Status -eq 200 -and $r.Obj.status -eq "Rejected" -and $r.Obj.rejectionReason) "PATCH reject #$toReject -> HTTP $($r.Status), estado $($r.Obj.status), motivo: $($r.Obj.rejectionReason)"

$r = Invoke-Api POST $BaseUrl (New-Request 760000)
$toRejectBlank = $r.Obj.id
$r = Invoke-Api PATCH "$BaseUrl/$toRejectBlank/reject" @{ reason = "   " }
$stillPending = (Invoke-Api GET "$BaseUrl/$toRejectBlank").Obj.status
Add-Result "T14" ($r.Status -eq 400 -and $stillPending -eq "Pending") "PATCH reject motivo '   ' -> HTTP $($r.Status), estado tras intento: $stillPending"

$r = Invoke-Api PATCH "$BaseUrl/$pendingId/approve" $null
Add-Result "T15" ($r.Status -eq 409) "PATCH approve sobre aprobada #$pendingId -> HTTP $($r.Status)"

$r = Invoke-Api PATCH "$BaseUrl/$toReject/reject" @{ reason = "Segundo intento" }
Add-Result "T16" ($r.Status -eq 409) "PATCH reject sobre rechazada #$toReject -> HTTP $($r.Status)"

# --- Informe --------------------------------------------------------------
$results | Format-Table -AutoSize
$failed = @($results | Where-Object Resultado -eq "FAIL")
Write-Host ("Total: {0} | PASS: {1} | FAIL: {2}" -f $results.Count, ($results.Count - $failed.Count), $failed.Count)
if ($failed.Count -gt 0) { exit 1 }
exit 0
