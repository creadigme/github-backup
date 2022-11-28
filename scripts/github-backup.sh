#!/bin/sh

# A script to backup Github repositories to a Synology.
# By Richard Bairwell. http://www.bairwell.com
# Edited by CREADIGME SAS
# MIT Licenced. https://github.com/creadigme/github-backup

# token from https://github.com/settings/tokens
# GITHUB_BACKUP_TOKEN=

# where should the files be saved
if [ -z "$GITHUB_BACKUP_PATH" ]; then
    echo "You must specify GITHUB_BACKUP_PATH env."
    exit -1
fi

# you shouldn't need to change anything below here - unless you have over 100 repos: in which case, see the bottom.
TOTALCOUNTER=0
PAGE=1
GIT="${GIT:="git"}"
RES_COUNT=100

API_URL_BASE=""

if [ -z "$GITHUB_BACKUP_TOKEN" ]
    then
        if [ -z "$GITHUB_BACKUP_USER" ]; then
            echo "You must specify GITHUB_BACKUP_USER env."
            exit -1
        fi
        API_URL_BASE="https://api.github.com/users/${GITHUB_BACKUP_USER}"
    else
        API_URL_BASE="https://api.github.com/user"
fi

fetch_fromUrl() {
    API_URL="${API_URL_BASE}/repos?type=all&per_page=100&page=${PAGE}"
    echo "Fetching from ${API_URL}"

    if [ -z "$GITHUB_BACKUP_TOKEN" ]
        then
            REPOS=`curl -s "${API_URL}" | jq -r 'values[] | "\(.full_name),\(.private),\(.git_url),\(.has_wiki)"'`
        else
            REPOS=`curl -H "Authorization: token ${GITHUB_BACKUP_TOKEN}" -s "${API_URL}" | jq -r 'values[] | "\(.full_name),\(.private),\(.git_url),\(.has_wiki)"'`
    fi

    RES_COUNT=0

    for REPO in $REPOS
    do
        RES_COUNT=$((RES_COUNT+1))
        TOTALCOUNTER=$((TOTALCOUNTER+1))
        REPONAME=`echo ${REPO} | cut -d ',' -f1`
        PRIVATEFLAG=`echo ${REPO} | cut -d ',' -f2`
        ORIGINALGITURL=`echo ${REPO} | cut -d ',' -f3`
        HASWIKI=`echo ${REPO} | cut -d ',' -f4`
        GITURL="https://oauth2:${GITHUB_BACKUP_TOKEN}@github.com/${REPONAME}.git"
        mkdir "${GITHUB_BACKUP_PATH}/${REPONAME}" -p
        REPOPATH="${GITHUB_BACKUP_PATH}/${REPONAME}/code"

        # Create a bare clone of the repository
        if [ -d "$REPOPATH" ]; then
            echo "Updating repo (--mirror): ${GITURL} to ${REPOPATH}"
            (cd ${REPOPATH} && ${GIT} remote update)
        else
            echo "Cloning repo (--mirror): ${GITURL} to ${REPOPATH}"
            ${GIT} clone --mirror ${GITURL} ${REPOPATH}
        fi

        # Pull in the repository's Git Large File Storage objects.
        (cd ${REPOPATH} && ${GIT} lfs fetch --all)
        if [ ! -z "$GITHUB_BACKUP_TOKEN" ] && [ "true"===${PRIVATEFLAG} ]
        then
            `touch ${GITHUB_BACKUP_PATH}/${REPONAME}/private`
        fi

        if [ "true"===${HASWIKI} ]; then
            WIKIPATH="${GITHUB_BACKUP_PATH}/${REPONAME}/wiki"
            WIKIURL="https://oauth2:${GITHUB_BACKUP_TOKEN}@github.com/${REPONAME}.wiki.git"

            if [ -d "$WIKIPATH" ]; then
                echo "Updating repo (--mirror): ${WIKIURL} to ${WIKIPATH}"
                (cd ${WIKIPATH} && ${GIT} remote update)
            else
                echo "Cloning wiki (--mirror): ${WIKIURL} to ${WIKIPATH}"
                ${GIT} clone --mirror ${WIKIURL} ${WIKIPATH}
            fi
        fi
    done
}

until [ $RES_COUNT -lt 100 ]; do
    fetch_fromUrl
    PAGE=$((PAGE+1))
done

echo $((TOTALCOUNTER)) repositories updated