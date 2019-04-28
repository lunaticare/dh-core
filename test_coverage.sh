#!/usr/bin/env bash

set -e
set -u
set -x

# the script assumes all necessary dependencies, including those needed for testing
# were installed during Stack build

ANALYZE_V=$ANALYZE_V
DENSE_LINEAR_ALGEBRA_V=$DENSE_LINEAR_ALGEBRA_V
DATASETS_V=$DATASETS_V
CODECOV_TOKEN=${CODECOV_TOKEN:-}
ARGS=$ARGS

# module analyze
function add_coverage() {
    module=$1
    version=$2
    echo "Calculating coverage for $module $version"
    pushd $module
    rm -rf dist/hpc
    # install extra dependencies from stack.yaml
    
    #needs to be installed from git@github.com:lunaticare/codecov-haskell.git@7fa0d6bf96ce6a488e13f48bc92281c757086780
    #cabal install codecov-haskell
    cabal clean
    stack install $ARGS
    cabal configure --enable-tests --enable-coverage
    cabal test
    # change code file paths from relative to current dirrectory to relative to Git repository root
    # so Codecov can display them on website
    # macOS version
    find dist/hpc -iname '*.mix' \
        -exec sed -i '.backup' -E \
        -e 's/(src\/.*\.hs")/'$module'\/&/g' \
        -e 's/(test\/.*\.hs")/'$module'\/&/g' \
        -e 's/(dist\/.*\.hs")/'$module'\/&/g' \
        {} \;
    # change dir so codecov-haskell can find source files
    cd ../
    # to simulate Travis locally export following variables:
    # TRAVIS=true
    # TRAVIS_JOB_ID=test-$(date "+%Y%m%d%H%M%S")
    # TRAVIS_COMMIT=$(git rev-parse HEAD)
    # TRAVIS_BRANCH=$(git branch | grep \* | cut -d ' ' -f2)
    if [ ! -z $CODECOV_TOKEN ] ;
    then
        codecov-haskell spec \
            --exclude-dir=$module/test \
            --exclude-dir=$module/dist \
            --display-report \
            --print-response \
            --combined=false \
            --mix-dir $module/dist/hpc/vanilla/mix/ \
            --tix-dir $module/dist/hpc/vanilla/tix/ \
            --token=$CODECOV_TOKEN
    fi        
    # mkdir -p dist/hpc/tix/all/
    # mv dist/hpc/tix/spec/spec.tix
    popd
}

echo "Install Cabal"
stack install cabal-install

echo "Install codecov-haskell"
if [ ! -d codecov-haskell ];
then
    git clone https://github.com/lunaticare/codecov-haskell --depth=1
fi
pushd codecov-haskell
git fetch --tags --progress origin '+refs/pull/*/head:refs/remotes/upstream/pr/*/head' --depth=1
git checkout 7fa0d6bf96ce6a488e13f48bc92281c757086780
stack install
popd

echo "Installing test dependencies"
stack install QuickCheck hspec

add_coverage analyze $ANALYZE_V
add_coverage dense-linear-algebra $DENSE_LINEAR_ALGEBRA_V
# datasets has no real tests
add_coverage datasets $DATASETS_V
# dh-core has no real tests
# add_coverage core $DATASETS_V