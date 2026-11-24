"""55-14 scratch pytest plugin (no pytest-repeat in the image): REPEAT=<n> runs every selected test n times."""
import os

import pytest


@pytest.fixture
def _repeat_step(request):
    return request.param


def pytest_generate_tests(metafunc):
    n = int(os.environ.get("REPEAT", "1"))
    if n > 1:
        metafunc.fixturenames.append("_repeat_step")
        metafunc.parametrize("_repeat_step", range(n), indirect=True)
