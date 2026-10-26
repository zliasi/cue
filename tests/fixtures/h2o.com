%chk=h2o.chk
%nprocshared=2
%mem=1GB
#p HF/STO-3G opt

water

0 1
O 0.0 0.0 0.0
H 0.0 0.0 0.96
H 0.93 0.0 -0.24

