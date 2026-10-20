"""`python3 agent-system/tools/installer <install|update|uninstall> …` (47-07). See genesis_installer.py."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from genesis_installer import main  # noqa: E402

sys.exit(main())
