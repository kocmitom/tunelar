# Tunelář

## Build

1. Install [Godot 4.7](https://godotengine.org/download) and its export templates (in the editor: Editor > Manage Export Templates > Download and Install).
2. In the project folder run:

```
godot --headless --path . --export-release "Windows Desktop" build/Tunelar.exe
```

3. Copy `build/Tunelar.exe` and `build/Tunelar.pck` to any PC and run the exe. Later versions arrive through the in-game LAN updater.

## Test

```
godot --headless --path . -s tests/test_runner.gd
```
