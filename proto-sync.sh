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
COMPONENTS_DIR=${EXONUM_REPO_ROOT}/components
NODE_PROTO_FILES_DIR=${EXONUM_REPO_ROOT}/exonum-node/src/proto
DST_PROTO_FILES_DIR=${CURR_DIR}/src
FILES_TO_EXCLUDE=(doc_tests.proto tests.proto)
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
rm -rf ${DST_PROTO_FILES_DIR}/*.proto

# Exclude known ignored files
exclusions=""
for file in ${FILES_TO_EXCLUDE[@]}
do
  exclusions="$exclusions--exclude=$file "
done

# Copy the proto files from various exonum crates to the destination
rsync -avh $exclusions \
  ${MAIN_PROTO_FILES_DIR}/*.proto \
  ${COMPONENTS_DIR}/proto/src/proto/*.proto \
  ${COMPONENTS_DIR}/crypto/src/proto/schema/*.proto \
  ${COMPONENTS_DIR}/merkledb/src/proto/*.proto \
  ${NODE_PROTO_FILES_DIR}/*.proto \
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

header "PUSHING CHANGES TO SERVER"

# At this step changes are considered verified so we can safely push everything.
git push origin ${CURR_BRANCH_NAME}

header "DONE"
