#/bin/bash
rm -rf build
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=../../labsound-distro ..
cmake --build . 
