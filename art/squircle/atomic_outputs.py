"""Replace generated files only after writing them completely.

Windows preview readers can permit replacement while denying direct truncation.
The sibling temporary file also leaves the previous asset intact on save failure.
"""
from contextlib import contextmanager
from pathlib import Path
import os
import tempfile


@contextmanager
def atomic_output(path):
    path = Path(path)
    fd, name = tempfile.mkstemp(prefix='.squircle-output-', suffix=path.suffix, dir=path.parent)
    os.close(fd)
    temporary = Path(name)
    try:
        yield temporary
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def save_image(image, path, **options):
    with atomic_output(path) as temporary:
        image.save(temporary, **options)
