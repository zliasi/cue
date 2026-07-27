.PHONY: test goldens check

test:
	python3 -m unittest discover -s tests

goldens:
	python3 tests/update-goldens.py

PY_FILES = cue.py migrate.py tests/test_cue.py tests/test_commands.py \
	tests/test_migrate.py tests/update-goldens.py

check:
	black --check $(PY_FILES)
	ruff check --select E4,E7,E9,F $(PY_FILES)
	mypy --strict cue.py migrate.py
