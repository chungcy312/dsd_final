$base = (Resolve-Path ..).Path
$pptx = Join-Path $base 'checkpoint\Check_Presentation.pptx'
if (Test-Path $pptx) { Remove-Item $pptx -Force }

$pp = New-Object -ComObject PowerPoint.Application
$pp.Visible = [Microsoft.Office.Core.MsoTriState]::msoTrue
$pp.DisplayAlerts = [Microsoft.Office.Interop.PowerPoint.PpAlertLevel]::ppAlertsNone
$pres = $pp.Presentations.Add()
$pres.PageSetup.SlideWidth = 960
$pres.PageSetup.SlideHeight = 540

function Add-Text($slide, $text, $x, $y, $w, $h, $size, $bold) {
    $shape = $slide.Shapes.AddTextbox(1, $x, $y, $w, $h)
    $shape.TextFrame.TextRange.Text = $text
    $shape.TextFrame.TextRange.Font.Size = $size
    $shape.TextFrame.TextRange.Font.Name = 'Microsoft JhengHei'
    if ($bold) { $shape.TextFrame.TextRange.Font.Bold = -1 }
    return $shape
}

function Add-Title($slide, $title) {
    Add-Text $slide $title 35 20 880 45 28 $true | Out-Null
    $line = $slide.Shapes.AddShape(1, 35, 70, 890, 2)
    $line.Fill.ForeColor.RGB = 7564574
    $line.Line.Visible = 0
}

$s = $pres.Slides.Add(1, 12)
Add-Text $s 'DSD Final Checkpoint' 120 130 720 70 40 $true | Out-Null
Add-Text $s 'Baseline checkpoint representation' 220 215 520 40 24 $false | Out-Null
Add-Text $s 'B12901008 Chung Chia-Yu' 290 285 420 40 24 $false | Out-Null
Add-Text $s 'May 28, 2026' 390 445 220 30 16 $false | Out-Null

$s = $pres.Slides.Add(2, 12)
Add-Title $s 'Synthesis Result'
Add-Text $s "Timing`nSynthesis clock period: 3.00 ns`nWorst negative slack: 0.00 ns`nTotal negative slack: 0.00 ns`nViolating paths: 0`nLogic levels: 10" 50 105 410 220 18 $false | Out-Null
Add-Text $s "Gate simulation`nPost-syn testbench cycle: 3.00 ns`nnoHazard sim. time: 1,407,896 ns`nhasHazard sim. time: 7,038,896 ns" 50 350 410 130 18 $false | Out-Null
Add-Text $s "Area summary`nCombinational area: 221,357.932724`nBuf/Inv area: 34,873.083013`nNoncombinational area: 178,868.619936`nMacro/Black Box area: 0.000000`nNet interconnect area: 3,749,825.752380`nTotal cell area: 400,226.552660`nTotal area: 4,150,052.305040" 500 105 410 360 17 $false | Out-Null

$s = $pres.Slides.Add(3, 12)
Add-Title $s 'Gate-Level Simulation'
$s.Shapes.AddPicture((Join-Path $base 'checkpoint\no_hazard.png'), 0, -1, 55, 115, 400, 230) | Out-Null
$s.Shapes.AddPicture((Join-Path $base 'checkpoint\has_hazard.png'), 0, -1, 505, 115, 400, 230) | Out-Null
Add-Text $s 'noHazard pattern' 160 350 200 25 15 $false | Out-Null
Add-Text $s 'hasHazard pattern' 610 350 200 25 15 $false | Out-Null
Add-Text $s 'Both baseline gate-level simulations pass with SDF annotation at 3.00 ns.' 90 420 780 40 20 $false | Out-Null

$s = $pres.Slides.Add(4, 12)
Add-Title $s 'Critical Path and Future Plan'
Add-Text $s "Cache hit datapath`nPC / D-cache address`n  -> index, tag, word offset decode`n  -> way0 tag compare and word select`n  -> way1 tag compare and word select`n  -> hit / way mux`n  -> pipeline register" 55 115 480 260 19 $false | Out-Null
Add-Text $s "Observation`nCache access and branch redirection paths are important timing targets for final performance." 570 115 330 120 18 $false | Out-Null
Add-Text $s "Next steps`n- Experiment with cache block count and way count`n- Tune I-cache/D-cache size and associativity`n- Experiment with branch prediction algorithms`n- Explore compressed and multiplication extensions" 570 270 340 190 17 $false | Out-Null

$s = $pres.Slides.Add(5, 12)
Add-Title $s 'Issues Encountered'
Add-Text $s "Reset input delay`nThe testbench changes reset at a different phase from the memory interface. Treating every input with the same delay caused misleading timing pressure and gate-level setup messages. The synthesis constraint was updated to use a separate reset input delay." 55 115 400 250 18 $false | Out-Null
Add-Text $s "Cache data reset`nCache data arrays do not need to be reset because the valid bits define whether a line can be used. Removing data-array reset reduced unnecessary reset mux paths, while keeping valid/dirty/control reset for correctness." 505 115 400 250 18 $false | Out-Null
Add-Text $s "Current status`nThe baseline processor supports the required checkpoint instruction set, handles structural/data/control hazards, includes cache flush support, and passes noHazard and hasHazard gate-level simulations at 3.00 ns." 90 410 780 85 18 $false | Out-Null

$pres.SaveAs($pptx)
$pres.Close()
$pp.Quit()
Write-Output $pptx
