$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
foreach($name in @('A','B','C','D','PIC5')){
 $bytes=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot "$name.ppm"))
 $offset=0;$lines=0
 while($lines-lt 3){if($bytes[$offset]-eq 10){$lines++};$offset++}
 if($bytes.Length-$offset-ne 640*480*3){throw "Incomplete PPM $name"}
 $bmp=[Drawing.Bitmap]::new(640,480,[Drawing.Imaging.PixelFormat]::Format24bppRgb)
 $data=$bmp.LockBits([Drawing.Rectangle]::new(0,0,640,480),[Drawing.Imaging.ImageLockMode]::WriteOnly,[Drawing.Imaging.PixelFormat]::Format24bppRgb)
 $raw=New-Object byte[] (640*480*3)
 for($i=0;$i-lt $raw.Length;$i+=3){$raw[$i]=$bytes[$offset+$i+2];$raw[$i+1]=$bytes[$offset+$i+1];$raw[$i+2]=$bytes[$offset+$i]}
 [Runtime.InteropServices.Marshal]::Copy($raw,0,$data.Scan0,$raw.Length)
 $bmp.UnlockBits($data)
 $bmp.Save((Join-Path $PSScriptRoot "$name.png"),[Drawing.Imaging.ImageFormat]::Png)
 $bmp.Dispose()
}
