# mathmath-pipeline

Offline content pipeline (D41). Owner-run on the Mac; never on the device.

```bash
uv sync                      # install (Python 3.14, see .python-version)
uv run ruff check . && uv run ruff format --check . && uv run pyright && uv run pytest
```

`core_cli(...)` wraps the Swift `core-cli` executable in `Packages/Core` (D42): L0 validation and layout
are implemented once, in `Core`, and invoked from here.
