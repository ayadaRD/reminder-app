$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$project = Join-Path $PSScriptRoot 'app'
if (Test-Path $project) { throw 'app already exists. Open it in VS Code to edit or run it.' }
flutter create --platforms=android --org ir.yadavar --android-language java --project-name yadavar $project
if ($LASTEXITCODE -ne 0) { throw 'flutter create failed' }
Copy-Item lib\*.dart app\lib -Force
Copy-Item native\*.java app\android\app\src\main\java\ir\yadavar\yadavar -Force
New-Item -ItemType Directory -Force app\android\app\src\main\res\raw | Out-Null
Copy-Item native\raw\*.wav app\android\app\src\main\res\raw -Force
[xml]$manifest = Get-Content app\android\app\src\main\AndroidManifest.xml -Raw
$ns = 'http://schemas.android.com/apk/res/android'
function Attr($node, $name, $value) { $node.SetAttribute($name,$ns,$value) | Out-Null }
foreach ($permission in @('POST_NOTIFICATIONS','SCHEDULE_EXACT_ALARM','RECEIVE_BOOT_COMPLETED','USE_FULL_SCREEN_INTENT','FOREGROUND_SERVICE','FOREGROUND_SERVICE_MEDIA_PLAYBACK','WAKE_LOCK')) {
  $node = $manifest.CreateElement('uses-permission')
  Attr $node 'name' "android.permission.$permission"
  $manifest.DocumentElement.PrependChild($node) | Out-Null
}
$app = $manifest.manifest.application
Attr $app 'label' 'یادآور'
foreach ($entry in @(@('receiver','.AlarmReceiver'),@('service','.RingService'),@('activity','.RingActivity'))) {
  $node = $manifest.CreateElement($entry[0])
  Attr $node 'name' $entry[1]
  Attr $node 'exported' 'false'
  if ($entry[0] -eq 'service') { Attr $node 'foregroundServiceType' 'mediaPlayback' }
  if ($entry[0] -eq 'receiver') {
    $filter = $manifest.CreateElement('intent-filter')
    foreach ($action in @('BOOT_COMPLETED','MY_PACKAGE_REPLACED','TIME_SET','TIMEZONE_CHANGED','SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED')) {
      $a = $manifest.CreateElement('action')
      $prefix = 'android.intent.action'
      if ($action -eq 'SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED') { $prefix = 'android.app.action' }
      Attr $a 'name' "$prefix.$action"
      $filter.AppendChild($a) | Out-Null
    }
    $node.AppendChild($filter) | Out-Null
  }
  $app.AppendChild($node) | Out-Null
}
$manifest.Save((Join-Path $project 'android\app\src\main\AndroidManifest.xml'))
Set-Location $project
$pubspec = Get-Content pubspec.yaml -Raw
$pubspec = $pubspec -replace '(?m)^dependencies:', "dependencies:`n  flutter_localizations:`n    sdk: flutter"
Set-Content pubspec.yaml $pubspec -Encoding utf8
flutter pub add shamsi_date
if ($LASTEXITCODE -ne 0) { throw 'Dependency installation failed' }
Remove-Item test\widget_test.dart -ErrorAction SilentlyContinue
Write-Host 'Ready. Open the app folder in VS Code.'
