"""Install library skills into the 53-11 test instance from the local genesis-workflows checkout.

GitLab's latest library tag (v0.25.0) does not hold `appian` (it is in the unpushed b097719), so the
local checkout is the library source here. Prints ids and versions only.
"""
import sys

from genesis.dist.local import LocalSource
from genesis.dist.skill_install import SkillInstaller
from genesis.runtime.settings import Settings

s = Settings.load()
assert str(s.state_dir).startswith("/tmp/genesis-53-11"), s.state_dir
inst = SkillInstaller(LocalSource("/Users/ramaswamy.u/repo-gitlab/ramaswamy.u/genesis-workflows"),
                      s.skills_dir, s.lockfile_path)
ids = sys.argv[1:]
lock = inst.install_selection(ids)
for i in ids:
    print(i, lock.skills[i].version, lock.skills[i].ref)
print("skills_dir", s.skills_dir)
