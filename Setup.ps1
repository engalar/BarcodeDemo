# GitHub API endpoint for retrieving repository contents
$apiUrl = "https://api.github.com/repos/engalar/MendixJavaPlayground/contents"

# Specify the file extension for filtering
$fileExtension = ".ps1"

# Make a request to GitHub API to get repository contents
$contents = Invoke-RestMethod -Uri $apiUrl -Method Get

# Filter the contents based on the file extension
$ps1Files = $contents | Where-Object { $_.type -eq "file" -and $_.name -match "$fileExtension$" }

# Download the .ps1 files to the current directory
foreach ($ps1File in $ps1Files) {
  $downloadUrl = $ps1File.download_url
  $filePath = Join-Path -Path (Get-Location) -ChildPath $ps1File.name
  Invoke-WebRequest -Uri $downloadUrl -OutFile $filePath

  # 读取文件内容
  $fileContent = Get-Content -Path $filePath -Encoding UTF8

  # 替换换行符（LF）为Windows风格的换行符（CRLF）
  $fileContent = $fileContent -replace "`n", "`r`n"

  # 将替换后的内容写回文件
  Set-Content -Path $filePath -Value $fileContent -Encoding UTF8
}

Write-Host "Download completed."
