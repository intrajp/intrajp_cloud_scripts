#!/bin/bash

# Refer: https://stackoverflow.com/questions/47006062/how-do-i-list-the-roles-associated-with-a-gcp-service-account

function usage()
{
  echo ""
  echo "How to use:"
  echo "$0 <ACCOUNT> <PROJECT_ID>"
  echo ""
}

ACCOUNT=$1
PROJECT=$2

if [ -z $1 ] || [ -z $2 ]; then 
  usage
  exit 1
fi

OUTPUTFILE_ROLES="${ACCOUNT}_roles.txt"
OUTPUTFILE_ROLES_TEMP="${ACCOUNT}_roles_temp.txt"
OUTPUTFILE_PERMISSIONS="${ACCOUNT}_permissions.txt"

gcloud projects get-iam-policy "${PROJECT}" --flatten="bindings[].members" --format='table(bindings.role)' --filter="bindings.members:${ACCOUNT}" | sed '/^[[:space:]]*$/d' > "${OUTPUTFILE_ROLES}"
awk -F":" '{print $2}' "${OUTPUTFILE_ROLES}" > "${OUTPUTFILES_ROLES_TEMP}"

while read line
do
  echo ""
  echo "=== ${line} ==="
  gcloud iam roles describe $line
done < "${OUTPUTFILE_ROLES_TEMP}" > "${OUTPUTFILE_PERMISSIONS}"

unlink "${OUTPUTFILE_PERMISSIONS}"

echo "Please check these files."
echo "${OUTPUTFILE_ROLES}"
echo "${OUTPUTFILE_PERMISSIONS}"
