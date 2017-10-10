#!/bin/bash 
source /opt/rh/devtoolset-4/enable
source /opt/rh/python27/enable
#/usr/bin/scl enable detoolset-4 bash
### externals setup script ###
wd=$(pwd)
### PYTHON BITS
#export pypath=/opt/Python-${PYTHON_VERSION}/build
#export LD_LIBRARY_PATH=${pypath}/lib:${LD_LIBRARY_PATH}
#export LIBRARY_PATH=${pypath}/lib:${LIBRARY_PATH}
#export PYTHONPATH=${pypath}/lib:${PYTHONPATH}
#export PATH=${pypath}/bin:${PATH}
#scl enable devtoolset-4 bash
cd /opt/root*
#export ROOTSYS=$(pwd)
#export PATH=${ROOTSYS}/bin
#export LD_LIBRARY_PATH=${ROOTSYS}/lib:${LD_LIBRARY_PATH}
source bin/thisroot.sh
#source $(find /opt -name thisroot.sh)
#echo "ROOT: ${ROOTSYS}"
cd /opt/geant-*/share/Geant*/geant4make
source geant4make.sh
cd ${wd}
### a lot more simple ## :)
export PATH=/apps:${PATH}
export PYTHONPATH=/DmpWorkflow/:${PYTHONPATH}

