# Convert the actual user BMPs into top-down RGB words for RTL simulation.
$ErrorActionPreference='Stop'
foreach($i in 0..3){
 $p=Join-Path $PSScriptRoot "../../../../resources/tf_card/PIC$($i+1).BMP"
 $b=[IO.File]::ReadAllBytes($p)
 if([BitConverter]::ToInt32($b,18)-ne 640 -or [BitConverter]::ToInt32($b,22)-ne 480 -or [BitConverter]::ToUInt16($b,28)-ne 24 -or [BitConverter]::ToUInt32($b,30)-ne 0){throw "Unsupported BMP: $p"}
 $offset=[BitConverter]::ToInt32($b,10)
 $w=[IO.StreamWriter]::new((Join-Path $PSScriptRoot "bg$i.hex"),$false,[Text.Encoding]::ASCII)
 try {for($y=0;$y-lt 480;$y++){for($x=0;$x-lt 640;$x++){$k=$offset+(479-$y)*1920+$x*3;$w.WriteLine(('{0:X2}{1:X2}{2:X2}' -f $b[$k+2],$b[$k+1],$b[$k]))}}}finally{$w.Dispose()}
}
