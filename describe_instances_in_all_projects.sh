#! /bin/bash
 
## Functions

## describe_instances_in_all_projects():This function describes instances in all the projects.

describe_instances_in_all_projects() {

  local api="compute.googleapis.com"
  local projects
  local is_api_available
  local instance_names
  local count
  local instance_t
  local zone_t

  echo ""
  echo "Start search"
  echo ""
  projects=$(gcloud projects list --format text | grep "projectId" | awk -F":" '{print $2}' | sed 's/[[:blank:]]//g' | tr '\n' ':')

  IFS=":", read -ra project_array <<< "${projects}"

  for project in "${project_array[@]}"
  do
    ## This shows the project id.
    echo "###"
    echo "${project}"

    ## This sets the project id.
    gcloud config set project "${project}" 2> /dev/null

    ## Skip if api is not enabled
    is_api_available=$(gcloud services list --enabled | grep "${api}") 2> /dev/null

    if [ ! -z "${is_api_available}" ]; then
      instance_names=$(gcloud compute instances list 2> /dev/null | grep -e "NAME\|ZONE" | awk -F":" '{print $2}' | sed 's/[[:blank:]]//g' | tr '\n' ':')
      if [ -z "${instance_names}" ]; then
        echo "No instance on this project."
        continue
      fi

      IFS=':', read -ra instance_array <<< "${instance_names}"
      count=0
      instance_t=""
      zone_t=""

      for instance_zone in "${instance_array[@]}"
      do
        if [ $((count)) == 0 ]; then
          instance_t="${instance_zone}"
        else
          zone_t="${instance_zone}"
          echo ""
          echo "=== ${project}:${instance_t}:${zone_t} ==="
          echo ""
          gcloud compute instances describe "${instance_t}" --zone="${zone_t}"
        fi

        count=$((count+1))
        if [ $count -eq 2 ]; then
          count=0
        fi
      done
    else
      echo "${api} is not enabled on this project"
    fi
  done
  echo ""
  echo "End search"
}

## Entry point
describe_instances_in_all_projects

exit 0
