$env:TPL_HOME = "..\native-template-barcode"
$env:TPL_VERSION = "v7.0.2"

$env:KEYSTORE_PASSWORD="mypass"
$env:KEYSTORE_ALIAS="temp"


. .\SetupCommon.ps1

$JDK8 = (FindJDK8Folder).FullName
$JDK11 = (FindJDK11Folder).FullName
$env:ANDROID_SDK_ROOT = "$env:SystemDrive\Android\android-sdk"

function _Update-GradleDistributionUrl {
  param(
    [string]$TplHome,
    [string]$NewUrl
  )

  # 构建文件路径
  $filePath = Join-Path $TplHome -ChildPath "android\gradle\wrapper\gradle-wrapper.properties"

  # 检查文件是否存在
  if (Test-Path $filePath -PathType Leaf) {
    # 使用 Select-String 查找以 distributionUrl 开头的整行
    $pattern = '^\s*distributionUrl.*'
    $line = Select-String -Path $filePath -Pattern $pattern

    # 如果找到匹配的行，则替换为新的内容
    if ($line) {
      $newLine = "distributionUrl=$NewUrl"
            (Get-Content $filePath) -replace $pattern, $newLine | Set-Content $filePath
      Write-Host "DistributionUrl in $filePath has been updated to $NewUrl"
    }
    else {
      Write-Host "No matching line found in $filePath"
    }
  }
  else {
    Write-Host "File not found: $filePath"
  }
}

function Update-GradleDistributionUrl {
  _Update-GradleDistributionUrl -TplHome $env:TPL_HOME -NewUrl "https://mirrors.aliyun.com/macports/distfiles/gradle/gradle-7.5.1-bin.zip"
}

$env:PRO_VERSION = Get-VersionNumber -FilePath $MprFile.Name

$originalLocation = Get-Location
$localMxHomePath = "$env:SystemDrive\progra~1\Mendix\$($env:PRO_VERSION)"
$mxbuildPath = "$env:SystemDrive\progra~1\Mendix\$($env:PRO_VERSION)\modeler\mxbuild.exe"
$keytoolPath = Join-Path -Path $env:JAVA_HOME -ChildPath "bin\keytool.exe"
$keystorePath = "temp-release-key.jks"


$javaHome = Join-Path -Path $JDK11 -ChildPath "bin\java.exe"
$mxbuildArgs = "--target=deploy --native-packager --loose-version-check --java-home=`"$JDK11`" --java-exe-path=`"$javaHome`" $MprFile"

function EnsureTplExist {
  if (Test-Path -Path "$env:TPL_HOME") {
    Write-Host "$env:TPL_HOME exists"
  }
  else {
    Write-Host "$env:TPL_HOME not exists"
    git clone --depth 1 --branch $env:TPL_VERSION https://gitee.com/engalar/native-template.git $env:TPL_HOME

    # Install dependencies
    Set-Location -Path "$env:TPL_HOME"
    npm install --registry=https://registry.npmmirror.com
    Set-Location -Path $originalLocation

    # Generate temporary keystore
    $keystoreParams = "-genkey -v -keystore $keystorePath -keyalg RSA -keysize 2048 -validity 10000 -alias temp -storepass mypass -keypass mypass -dname ""CN=Temp, OU=Temp, O=Temp, L=Temp, S=Temp, C=Temp"""

    Start-Process -FilePath "$keytoolPath" -ArgumentList "$keystoreParams" -Wait -WorkingDirectory $env:TPL_HOME\android\app
  }
}

function BuildMendixForNative {
  Invoke-Expression "$mxbuildPath $mxbuildArgs"
}

function CopyNativeAsset {
  Copy-Item -Recurse -Force "deployment\native\bundle\android\*" "$env:TPL_HOME\android\app\src\main"
}

$gradleBuildFile = "$env:TPL_HOME/android/app/build.gradle"
function _PatchGradleBuildFile {
  # TODO 临时解决方案，后续需要修改，根据hash安全地替换 https://gist.github.com/engalar/ba065c94fcceaa425185c4c4788f335f
  if (Select-String -Path $gradleBuildFile -Pattern "temp-release-key.jks") {
    Write-Host  "temp-release-key.jks exists, skip set debug signingConfig"
  }
  else {
    Write-Host  "temp-release-key.jks not exists, set debug signingConfig"
    $gradleBuildContent = Get-Content -Path $gradleBuildFile -Raw
    $gradleBuildContent = $gradleBuildContent -replace "debug {", "debug {`n        signingConfig signingConfigs.debug"
    $gradleBuildContent = $gradleBuildContent -replace "release {", "release {`n        signingConfig signingConfigs.release"
    $gradleBuildContent = $gradleBuildContent -replace "buildTypes {", "signingConfigs {`n        debug {`n            storeFile file(`"$keystorePath`")`n            storePassword `"$env:KEYSTORE_PASSWORD`"`n            keyAlias `"$env:KEYSTORE_ALIAS`"`n            keyPassword `"$env:KEYSTORE_PASSWORD`"`n        }`n        release {`n            storeFile file(`"$keystorePath`")`n            storePassword `"$env:KEYSTORE_PASSWORD`"`n            keyAlias `"$env:KEYSTORE_ALIAS`"`n            keyPassword `"$env:KEYSTORE_PASSWORD`"`n        }`n    }`n`n    buildTypes {"
    $gradleBuildContent | Set-Content -Path $gradleBuildFile
  }
}

function _DownloadAndReplaceFile {
  param (
    [string]$sourceUrl,
    [string]$targetPath
  )

  # 使用 Invoke-WebRequest 下载源文件
  $response = Invoke-WebRequest -Uri $sourceUrl

  # 将下载的内容保存到目标文件中
  $response.Content | Set-Content -Path $targetPath

  Write-Host "文件已下载并替换: $targetPath"
}

function SpeedupForChina {
  $sourceUrl = "https://gist.github.com/engalar/ba065c94fcceaa425185c4c4788f335f/raw/7c4dbf903b74406dcaf83a515761720595bd5aff/build_workspace.gradle"
  $targetPath = "$env:TPL_HOME\android\build.gradle"
  _DownloadAndReplaceFile -sourceUrl $sourceUrl -targetPath $targetPath
}

function _SetRuntimeUrl {
  param (
    [string]$runtime_url
  )
  $filePath = Join-Path $env:TPL_HOME "android\app\src\main\res\raw\runtime_url"
  Set-Content -Path $filePath -Value $runtime_url -NoNewline
}
function _DryBuild {
  $env:JAVA_HOME = $JDK11
  $env:PATH = "$JDK11\bin;$env:PATH;$env:PATH_BAK"
  Set-Location -Path "$env:TPL_HOME\android"

  .\gradlew.bat installDevDebug

  Set-Location -Path $originalLocation
  $env:PATH = $env:PATH_BAK
}
function _BuildAndRun {
  Set-Location -Path "$env:TPL_HOME"
  npx react-native run-android --variant=DevDebug 
  Set-Location -Path $originalLocation
}
function BuildAndroid {
  # 准备阶段（只用执行一次）
  EnsureTplExist
  SpeedupForChina
  _PatchGradleBuildFile # fixme
  _SetRuntimeUrl "192.168.2.22:8080"

  # 构建阶段
  BuildMendixForNative # Mendix->Native asset
  CopyNativeAsset # Copy asset to react native project
  _DryBuild # build react native project
  # _BuildAndRun

  # Show apk
  explorer.exe $env:TPL_HOME\android\app\build\outputs\apk\appstore\debug
}
