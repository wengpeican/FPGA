$ErrorActionPreference = 'Stop'
Push-Location $PSScriptRoot
try {
 $rtl = '../../user_source/hdl_source/SD'
 & iverilog -g2012 -s tb_lesson2 -o lesson2.vvp tb_lesson2.v "$rtl/sd_card_bmp.v" "$rtl/bmp_read.v" "$rtl/sd_card_top.v" "$rtl/sd_card_sec_read_write.v" "$rtl/sd_card_cmd.v" "$rtl/spi_master.v"
 if ($LASTEXITCODE -ne 0) { throw 'Compile failed' }
 & vvp lesson2.vvp | Tee-Object -FilePath simulation.log
 if ($LASTEXITCODE -ne 0) { throw 'Simulation failed' }
} finally { Pop-Location }