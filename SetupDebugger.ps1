. .\SetupCommon.ps1


function SetupDebugger_Init () {
  if (!(Test-Path -Path ".vscode") ) {
    New-Item -Path ".vscode" -ItemType "directory"
    # "https://github.com/engalar/MendixJavaPlayground"
    $sourcePath = ".vscode_tpl"
    $destinationPath = ".\.vscode"

    # 下载GitHub仓库的目录结构
    $apiUrl = "https://api.github.com/repos/engalar/MendixJavaPlayground/contents/$sourcePath"
    $response = Invoke-RestMethod -Uri $apiUrl

    foreach ($file in $response) {
      if ($file.type -eq "file") {
        $fileUrl = $file.download_url
        $fileName = $file.name
        $destinationFile = Join-Path -Path $destinationPath -ChildPath $fileName
        Invoke-WebRequest -Uri $fileUrl -OutFile $destinationFile
      }
    }
  }
}


$JDK8FolderName = (FindJDK8Folder).Name
$JDK11FolderName = (FindJDK11Folder).Name
$JDK17FolderName = (FindJDK17Folder).Name

$MprFile = Get-ChildItem -Filter "*.mpr"
$ProjectName = FindJavaProjectName
$SpVersion = Get-VersionNumber -FilePath $MprFile.Name

SetupDebugger_Init


(Get-Content -Raw -Path ".vscode/tasks.json") `
  -replace '\$ProjectName\$', $ProjectName `
  -replace '\$SystemDrive\$', $env:SystemDrive `
  -replace '\$SpVersion\$', $SpVersion `
  -replace '\$JDK11Folder\$', $JDK11FolderName `
  -replace '\$MprName\$', $MprFile.BaseName `
| Set-Content -Path ".vscode/tasks.json"

(Get-Content -Raw -Path ".vscode/launch.json") `
  -replace '\$ProjectName\$', $ProjectName `
  -replace '\$SystemDrive\$', $env:SystemDrive `
  -replace '\$SpVersion\$', $SpVersion `
  -replace '\$JDK11Folder\$', $JDK11FolderName `
  -replace '\$MprName\$', $MprFile.BaseName `
| Set-Content -Path ".vscode/launch.json"

(Get-Content -Raw -Path ".vscode/settings.json") `
  -replace '\$SystemDrive\$', $env:SystemDrive `
  -replace '\$JDK17Folder\$', $JDK17FolderName `
| Set-Content -Path ".vscode/settings.json"
