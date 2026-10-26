import os
from pathlib import Path

from ase import Atoms
from gpaw import GPAW

out = Path(os.environ["CUE_OUTDIR"])
atoms = Atoms("H2", positions=[[0, 0, 0], [0, 0, 0.74]], cell=[6, 6, 6])
atoms.center()
atoms.calc = GPAW(mode="lcao", basis="sz(dzp)", xc="PBE", txt=str(out / "h2.txt"))
print("energy", atoms.get_potential_energy())
