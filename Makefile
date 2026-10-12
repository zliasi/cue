.PHONY: test check goldens

PY = $(wildcard bin/cue tests/*.py)
SH = $(wildcard lib/*.sh templates/*.sbatch contrib/*.sbatch)

test:
	$(if $(wildcard tests/test_*.py),python3 -m unittest discover -s tests)
	$(if $(wildcard tests/lib/*.bats),bats tests/lib)

# Regenerates tests/expected from the current engine, inspect the diff.
goldens:
	CUE_UPDATE_GOLDENS=1 python3 -m unittest discover -s tests

check:
	$(if $(PY),black --check $(PY))
	$(if $(PY),ruff check $(PY))
	$(if $(PY),mypy --strict $(PY))
	$(if $(SH),shellcheck $(SH))
	$(if $(SH),shfmt -i 2 -ci -d $(SH))
