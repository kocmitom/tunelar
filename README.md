# Tunneler

## Build

1. Install [Godot 4.7](https://godotengine.org/download) and its export templates (in the editor: Editor > Manage Export Templates > Download and Install).
2. In the project folder run:

```
godot --headless --path . --export-release "Windows Desktop" build/Tunneler.exe
```

3. Copy `build/Tunneler.exe` and `build/Tunneler.pck` to any PC and run the exe. Later versions arrive through the in-game LAN updater.

## Test

```
godot --headless --path . -s tests/test_runner.gd
```
