#!/bin/bash
env -i
set -ex

sudo rm -fr *
git clone git@github.com:ljacobford/cicd_poc.git
echo "This is where the specs/tests would run."
tar -czvf myapp.tar -C cicd_poc .
echo "build complete. copy worked."
