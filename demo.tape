Output assets/flutter_sanity_demo.gif

Set Shell "powershell"
Set FontSize 15
Set FontFamily "Consolas"
Set Width 1200
Set Height 650
Set Padding 15
Set BorderRadius 8
Set Framerate 20
Set Theme "Catppuccin Mocha"

Type "clear"
Enter
Sleep 500ms

# Sol taraf simülasyonu: Ham Flutter Hatası
Type "Write-Host '=== [BEFORE] Raw flutter test: 4,000 Lines Overflow ===' -ForegroundColor Red"
Enter
Sleep 500ms

Type "flutter test benchmark/fixture_app/test/scenario1_vertical_overflow_test.dart"
Enter
Sleep 2s

# Sağ taraf simülasyonu: flutter-sanity-mcp
Type "Write-Host '=== [AFTER] flutter-sanity-mcp: 12 Lines Clean JSON ===' -ForegroundColor Green"
Enter
Sleep 500ms

Type "dart run benchmark/run_benchmark.dart"
Enter
Sleep 2s

Sleep 3s
