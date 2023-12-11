function FindJavaProjectName {
  return (Get-ChildItem -Filter "*.launch").BaseName
}

function FindJDK11Folder {
  $systemDrive = $env:SystemDrive
  $eclipsePath = Join-Path -Path $systemDrive -ChildPath 'Program Files\Eclipse Adoptium'

  $jdkFolders = Get-ChildItem -Path $eclipsePath -Directory | Where-Object { $_.Name -like 'jdk-11.*' } | Select-Object -First 1

  return $jdkFolders
}

function FindJDK17Folder {
  $systemDrive = $env:SystemDrive
  $eclipsePath = Join-Path -Path $systemDrive -ChildPath 'Program Files\Java'

  $jdkFolders = Get-ChildItem -Path $eclipsePath -Directory | Where-Object { $_.Name -like 'jdk-17.*' } | Select-Object -First 1

  return $jdkFolders
}


function FindJDK8Folder {
  $systemDrive = $env:SystemDrive
  $eclipsePath = Join-Path -Path $systemDrive -ChildPath 'Program Files\Java'

  $jdkFolders = Get-ChildItem -Path $eclipsePath -Directory | Where-Object { $_.Name -like 'jdk1.8.*' } | Select-Object -First 1

  return $jdkFolders
}

function Get-VersionNumber {
  param (
    [string]$FilePath
  )

  # 获取文件内容
  $content = Get-Content -TotalCount 30 -Path $FilePath

  # 定义匹配版本号的正则表达式
  $pattern = '(\d+\.\d+\.\d+\.\d+)\1'

  # 从文本中提取版本号
  $matches = [regex]::Matches($content, $pattern)

  # 如果找到版本号，返回版本号，否则抛出错误
  if ($matches.Count -gt 0) {
    $version = $matches[0].Groups[1].Value
    return $version
  }
  else {
    throw "未找到版本号"
  }
}

$MprFile=Get-ChildItem -Filter "*.mpr"
$env:PATH_BAK=$env:PATH
