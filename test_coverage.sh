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

stack_exec="stack $ARGS exec --no-ghc-package-path --"

# module analyze
function add_coverage() {
    module=$1
    version=$2
    echo "Calculating coverage for $module $version"
    pushd $module
    rm -rf dist/hpc
    # install extra dependencies from stack.yaml
    
    # $stack_exec cabal clean
    $stack_exec cabal install --only-dependencies
    $stack_exec cabal configure --enable-tests --enable-coverage
    $stack_exec cabal test
    # change code file paths from relative to current dirrectory to relative to Git repository root
    # so Codecov can display them on website
    # macOS version
    find dist/hpc -iname '*.mix' \
        -exec sed -i '.backup' -E \
        -e 's/(src\/.*\.hs")/'$module'\/&/g' \
        -e 's/(test\/.*\.hs")/'$module'\/&/g' \
        -e 's/(dist\/.*\.hs")/'$module'\/&/g' \
        {} \;
    # move analysis results - required for codecov-haskell to find them
    if [ -d dist/hpc/vanilla/mix/spec ] ;
    then
        mkdir -p dist/hpc/vanilla/mix/$module-$version/spec/
        cp -R dist/hpc/vanilla/mix/spec/ \
            dist/hpc/vanilla/mix/$module-$version/
    fi
    # change dir so codecov-haskell can find source files
    cd ../
    # to simulate Travis locally export following variables:
    # TRAVIS=true
    # TRAVIS_JOB_ID=test-$(date "+%Y%m%d%H%M%S")
    # TRAVIS_COMMIT=$(git rev-parse HEAD)
    # TRAVIS_BRANCH=$(git branch | grep \* | cut -d ' ' -f2)
    if [ ! -z $CODECOV_TOKEN ] ;
    then
        travis_retry codecov-haskell spec \
            --exclude-dir=$module/test \
            --exclude-dir=$module/dist \
            --display-report \
            --print-response \
            --combined=false \
            --mix-dir $module/dist/hpc/vanilla/mix/ \
            --mix-dir $module/dist/hpc/vanilla/mix/${module}*/ \
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
git checkout 4eca32c1f87d32136b035e647dc4c2f4da89c1f9
# faster with the same Stackage image
stack $ARGS install
popd

$stack_exec cabal update

echo "Installing test dependencies"
$stack_exec cabal install QuickCheck hspec

add_coverage analyze $ANALYZE_V
add_coverage dense-linear-algebra $DENSE_LINEAR_ALGEBRA_V
# datasets has no real tests
add_coverage datasets $DATASETS_V
# dh-core has no real tests
# add_coverage core $DATASETS_V