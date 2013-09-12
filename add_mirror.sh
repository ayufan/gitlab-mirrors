#!/bin/bash
#Tue Sep 10 23:01:08 EDT 2013
#USAGE
#  ./add_mirror.sh --git --project-name

#bash option stop on first error
set -e

#Include all user options and dependencies
git_mirrors_dir="$(dirname "${0}")"
cd "${git_mirrors_dir}"
. "config.sh"
. "lib/VERSION"
. "lib/functions.sh"

PROGNAME="${0##*/}"
PROGVERSION="${VERSION}"

#Default script options
svn=false
git=false
project_name=""
mirror=""

#
# ARGUMENT HANDLING
#
usage()
{
  cat <<EOF
${PROGNAME} ${PROGVERSION} - MIT License by Sam Gleske

USAGE:
  ${PROGNAME} --git|--svn --project NAME --mirror URL

DESCRIPTION:
  This will add a git or SVN repository to be mirrored by GitLab.  It 
  first checks to see if the project exists in gitlab.  If it does
  not exist then it creates it.  It will then clone and check in the
  first copy into GitLab.  From there you must use the update_mirror.sh
  script or git git-mirrors.sh script.

  -h,--help          Show help
  -v,--version       Show program version
  --git              Mirror a git repository (must be explicitly set)
  --svn              Mirror a SVN repository (must be explicitly set)
  --project-name NAME
                     Set a GitLab project name to NAME.
  --mirror URL       Repository URL to be mirrored.


EOF
}
#Short options are one letter.  If an argument follows a short opt then put a colon (:) after it
SHORTOPTS="hvm:p:"
LONGOPTS="help,version,git,svn,mirror:,project-name:"
ARGS=$(getopt -s bash --options "${SHORTOPTS}" --longoptions "${LONGOPTS}" --name "${PROGNAME}" -- "$@")
eval set -- "$ARGS"
while true; do
  case $1 in
    -h|--help)
        usage
        exit 1
      ;;
    -v|--version)
        echo "${PROGNAME} ${PROGVERSION}"
        exit 1
      ;;
    --git)
        git=true
        shift
      ;;
    --svn)
        svn=true
        shift
      ;;
    -p|--project-name)
        project_name="${2}"
        shift 2
      ;;
    -m|--mirror)
        mirror="${2}"
        shift 2
      ;;
    --)
        shift
        break
      ;;
    *)
        shift
        break
      ;;
    esac
done

#
# Program functions
#

function preflight() {
  STATUS=0
  if ${git} && ${svn};then
    red_echo -n "Must not set " 1>&2
    yellow_echo -n "--svn" 1>&2
    red_echo -n " and " 1>&2
    yellow_echo -n "--git" 1>&2
    red_echo " options.  Choose one or other." 1>&2
    STATUS=1
  fi
  if ! ${git} && ! ${svn};then
    red_echo -n "Must specify the " 1>&2
    yellow_echo -n "--git" 1>&2
    red_echo -n " or " 1>&2
    yellow_echo -n "--svn" 1>&2
    red_echo " options." 1>&2
    STATUS=1
  fi
  if [ -z "${project_name}" ];then
    red_echo -n "Missing " 1>&2
    yellow_echo -n "--project-name" 1>&2
    red_echo " option." 1>&2
    STATUS=1
  fi
  if [ -z "${mirror}" ];then
    red_echo -n "Missing " 1>&2
    yellow_echo -n "--mirror" 1>&2
    red_echo " option." 1>&2
    STATUS=1
  fi
  return ${STATUS}
}

#
# Main execution
#

#Run a preflight check on options for compatibility.
if ! preflight;then
  echo "Command aborted due to previous errors." 1>&2
  exit 1
fi
#Check for namespace directory existence
if [ ! -e "${repo_dir}/${gitlab_namespace}" ];then
  mkdir -p "${repo_dir}/${gitlab_namespace}"
elif [ ! -d "${repo_dir}/${gitlab_namespace}" ];then
  red_echo "Error: \"${repo_dir}/${gitlab_namespace}\" exists but is not a directory." 1>&2
  exit 1
fi

#Set up project creation options based on config.sh to be passed to create manage_gitlab_project.py
CREATE_OPTS=""
if ${issues_enabled};then
  CREATE_OPTS="--issues ${CREATE_OPTS}"
fi
if ${wall_enabled};then
  CREATE_OPTS="--wall ${CREATE_OPTS}"
fi
if ${merge_requests_enabled};then
  CREATE_OPTS="--merge ${CREATE_OPTS}"
fi
if ${wiki_enabled};then
  CREATE_OPTS="--wiki ${CREATE_OPTS}"
fi
if ${snippets_enabled};then
  CREATE_OPTS="--snippets ${CREATE_OPTS}"
fi
if ${public};then
  CREATE_OPTS="--public ${CREATE_OPTS}"
fi

#export env vars for python script
export gitlab_user_token_secret gitlab_url gitlab_namespace gitlab_user

 

if ${git};then
  #Get the remote gitlab url for the specified project.
  #If the project doesn't already exist in gitlab then create it.
  echo "Resolving gitlab remote."
  if python lib/manage_gitlab_project.py --create ${CREATE_OPTS} "${project_name}" 1> /dev/null;then
    gitlab_remote=$(python lib/manage_gitlab_project.py --create ${CREATE_OPTS} "${project_name}")
    echo "gitlab remote ${gitlab_remote}"
  else
    echo "There was an unknown issue with manage_gitlab_project.py" 1>&2
    exit 1
  fi
  if [ -z "${gitlab_remote}" ];then
    echo "There was an unknown issue with manage_gitlab_project.py" 1>&2
    exit 1
  fi

  #create a mirror
  echo "Creating mirror from ${mirror}"
  cd "${repo_dir}/${gitlab_namespace}"
  git clone --mirror ${mirror} "${project_name}"
  cd "$1"
  #add the gitlab remote
  echo "Adding gitlab remote to project."
  git remote add gitlab ${gitlab_remote}
  git config --add remote.gitlab.push '+refs/heads/*:refs/heads/*'
  git config --add remote.gitlab.push '+refs/tags/*:refs/tags/*'
  #Check the initial repository into gitlab
  echo "Checking the mirror into gitlab."
  git fetch
  git remote prune origin
  git push gitlab
  echo "All done!"
fi














exit

#create a mirror
echo "Creating mirror from $2"
cd "${repo_dir}/${gitlab_namespace}"
git clone --mirror $2 "$1"
cd "$1"
#add the gitlab remote
echo "Adding gitlab remote to project."
git remote add gitlab ${gitlab_remote}
git config --add remote.gitlab.push '+refs/heads/*:refs/heads/*'
git config --add remote.gitlab.push '+refs/tags/*:refs/tags/*'
#Check the initial repository into gitlab
echo "Checking the mirror into gitlab."
git fetch
git remote prune origin
git push gitlab
echo "All done!"
