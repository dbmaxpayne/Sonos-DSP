param(
  [Parameter(Mandatory=$true)]
  [String]$inputPath,
  [int]$chipSize=64 # In KBit
  )

$bytes = Get-Content $inputPath -Encoding Byte

$rows    = 0
$hexString = for($rows=0; $rows -lt ($chipSize*1024/8); $rows=$rows+15)
    {
        "$('{0:x4}' -f $rows):  $(for($int=0; $int -le 15; $int++)
            {
                if ($int % 4 -eq 0 -and $int -ne 0)
                    {
                        " "
                    }
                if ($bytes[$rows+$int] -ne $null)
                    {
                        $(([System.BitConverter]::ToString($bytes[$rows+$int])).ToLower())
                    }
                else
                    {
                        "00"
                    }
                
            })`n"

        $rows = $rows + 1
    }

$hexString = $hexString -replace '   ','  '
$hexstring = $hexString.TrimEnd(' ')
#$hexString = $hexString -replace '\r\n', '\n'

$hexString | Set-Content "$($inputPath | Split-Path -Parent)\$((Get-Item $inputPath).BaseName).pshex" -NoNewline