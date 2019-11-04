#!/usr/bin/env bash

# This script synchronyzes exonum protobuf specification files with the `exonum-proto-sources` repository, where they
# could be used by various Exonum clients.
#
# It is supposed that repo with proto files has the same branches as exonum repo. Thus, this allows to have different
# sets of proto files for certain branch. Also, script updates proto files for current branch only. For example, in
# order to sync files for exonum branch "feature_X", one should execute this script from the local branch "feature_X".
#
# This script is intended to be used by Exonum developers in order to update Exonum clients with stable changes in the
# proto files.

set -eu -o pipefail

# prints a section header
function header() {
    local title=$1
    local rest="========================================================================"
    echo
    echo "===[ ${title} ]${rest:${#title}}"
    echo
}

if [ "$#" -ne 1 ]
  then
    echo "Usage:
     $0 REV"
    echo "Where REV is the revision of the source 'exonum' repository."
    exit 1
fi

REV="$1"

EXONUM_REPO_URI="https://github.com/exonum/exonum.git"
EXONUM_REPO_TMP_DIR="/tmp/_exonum_repo_tmp"

CURR_DIR=$(pwd)
EXONUM_REPO_ROOT=${EXONUM_REPO_TMP_DIR}
MAIN_PROTO_FILES_DIR=${EXONUM_REPO_ROOT}/exonum/src/proto/schema/exonum
COMPONENTS_DIR=${EXONUM_REPO_ROOT}/components
DST_PROTO_FILES_DIR=${CURR_DIR}/src
CURR_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Clean temporary dir from the previous iteration if any
rm -fR ${EXONUM_REPO_TMP_DIR}

header "CLONING REPO"

git clone --depth 30 --single-branch --branch ${CURR_BRANCH_NAME} ${EXONUM_REPO_URI} ${EXONUM_REPO_TMP_DIR}
cd ${EXONUM_REPO_TMP_DIR}
git reset --hard ${REV}
cd ${CURR_DIR}

header "COPYING PROTO FILES"

# Copy main files
cp -v ${MAIN_PROTO_FILES_DIR}/blockchain.proto ${DST_PROTO_FILES_DIR}
cp -v ${MAIN_PROTO_FILES_DIR}/consensus.proto ${DST_PROTO_FILES_DIR}
cp -v ${MAIN_PROTO_FILES_DIR}/runtime.proto ${DST_PROTO_FILES_DIR}
# Common
cp -v ${COMPONENTS_DIR}/proto/src/proto/common.proto ${DST_PROTO_FILES_DIR}
# Crypto stuff
cp -v ${COMPONENTS_DIR}/crypto/src/proto/schema/types.proto ${DST_PROTO_FILES_DIR}
# Proofs
cp -v ${COMPONENTS_DIR}/merkledb/src/proto/map_proof.proto ${DST_PROTO_FILES_DIR}
cp -v ${COMPONENTS_DIR}/merkledb/src/proto/list_proof.proto ${DST_PROTO_FILES_DIR}

header "SYNCING PROTO FILES IN REPO"
# Prepare the commit message.
# The commit message contains revision, name of the source branch and tags.

# The `Tags` line inserted only if tags are presented for this revision.
# Note: The `git describe --tags` fails if there are no tags presented, thus, in order to not to break the whole script
# execution this case is wrapped with `|| echo -n`.
TAGS_LINE=$(TAGS=$(git describe --tags --exact-match ${REV} 2>/dev/null) && echo -n "Tags: ${TAGS}" || echo -n)

COMMIT_MESSAGE=$(cat << EOF
Synchronizing Exonum proto files.

Exonum revision: exonum/exonum@${REV}
Source branch: ${CURR_BRANCH_NAME}
${TAGS_LINE}
EOF
)

# User is required to go through changes and confirm or dismiss every changeset.
git commit -p -m "${COMMIT_MESSAGE}" -e src

header "PUSHING CHANGES TO SERVER"

# At this step changes are considered verified so we can safely push everything.
git push origin ${CURR_BRANCH_NAME}

header "DONE"
