# exonum-proto-sources
This repository is for protobuf specification files for the Exonum blokchain framework. 

## How to Use
This repo provides `proto-sync.sh` script which automatically synchronizes proto files 
with the given revision in the original repository.

## Example
Let's assume you are using this repo as git submodule in your project and would like
to deliver new changes from Exonum master branch to your feature branch.
```shell script
git checkout -b my-feature-branch
cd exonum-java-binding/common/src/main/proto # enter the submodule dir
# Now we are working with exonum-proto-sources repo
git fetch
git checkout master
./proto-sync.sh 228d861544a93a65961e021cb6838c8180675861 # specify desired revision id
# It will ask you to review all changes and then pushes them to the remote
cd .. # go to main repo
git commit -am "sync complete" # now you reflacted submodule changes in your branch
``` 
