#!/usr/bin/env bash

# This script synchronyzes exonum protobuf specification files with the `exonum-proto-sources` repository, where they
# could be used by various Exonum clients.
#
# It is supposed that exonum-proto-sources repository has the same branches as Exonum one. The script does not perform
# checkout, so it must be executed from the local branch with the name equal to the name of the target Exonum repository
# branch.
#
# This script is intended to be used by Exonum developers in order to update Exonum clients with changes in the
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
EXONUM_NODE_PROTO_FILES_DIR=${EXONUM_REPO_ROOT}/exonum-node/src/proto
COMPONENTS_DIR=${EXONUM_REPO_ROOT}/components
DST_PROTO_FILES_DIR=${CURR_DIR}/src/exonum
CURR_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Clean temporary dir from the previous iteration if any
rm -fR ${EXONUM_REPO_TMP_DIR}

header "CLONING REPO"

git clone --depth 30 --single-branch --branch ${CURR_BRANCH_NAME} ${EXONUM_REPO_URI} ${EXONUM_REPO_TMP_DIR}
cd ${EXONUM_REPO_TMP_DIR}
git reset --hard ${REV}

# The `Tags` line inserted only if tags are presented for this revision.
# Note: The `git describe --tags` fails if there are no tags presented, thus, in order to not to break the whole script
# execution this case is wrapped with `|| echo -n`.
TAGS_LINE=$(TAGS=$(git describe --tags --exact-match ${REV} 2>/dev/null) && echo -n "Tags: ${TAGS}" || echo -n)

cd ${CURR_DIR}

header "COPYING PROTO FILES"
# Remove the present proto files so that there are no stale files.
rm -rf ${DST_PROTO_FILES_DIR}/*

# Copy the proto files from various exonum crates to the destination
rsync -avh \
  ${MAIN_PROTO_FILES_DIR}/ \
  ${DST_PROTO_FILES_DIR}

rsync -avh \
  ${COMPONENTS_DIR}/proto/src/proto/exonum/common \
  ${DST_PROTO_FILES_DIR}

rsync -avh \
  ${COMPONENTS_DIR}/crypto/src/proto/schema/exonum/crypto \
  ${DST_PROTO_FILES_DIR}

rsync -avh \
  ${COMPONENTS_DIR}/merkledb/src/proto/exonum/proof \
  ${DST_PROTO_FILES_DIR}

rsync -avh \
  ${EXONUM_NODE_PROTO_FILES_DIR}/consensus.proto \
  ${DST_PROTO_FILES_DIR}

header "SYNCING PROTO FILES IN REPO"
# Prepare the commit message.
# The commit message contains revision, name of the source branch and tags.
COMMIT_MESSAGE=$(cat << EOF
Synchronizing Exonum proto files.

Exonum revision: exonum/exonum@${REV}
Source branch: ${CURR_BRANCH_NAME}
${TAGS_LINE}
EOF
)

# Update REVISION.txt file
echo ${REV} > "REVISION.txt"
git add REVISION.txt

# User is required to go through changes and confirm or dismiss every changeset.
git add src
git commit -p -m "${COMMIT_MESSAGE}" -e src

header "DONE, you can now push the changes on remote"
