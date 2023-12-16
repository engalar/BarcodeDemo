$firstAvd = & "$env:SystemDrive\Android\android-sdk\emulator\emulator.exe" -list-avds | Select-Object -First 1
& "$env:SystemDrive\Android\android-sdk\emulator\emulator.exe" -avd $firstAvd