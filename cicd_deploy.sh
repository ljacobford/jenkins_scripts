#!/bin/bash
env -i
set -e

cmd=`sudo aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[0] .LoadBalancerNames'`
  
  if [[ $cmd == '[]' ]]; then
      deploy_group=$(bash -c "sudo aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[0] .AutoScalingGroupName'")
  else
      deploy_group=$(bash -c "sudo aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[1] .AutoScalingGroupName'")
  fi
  group_trimmed=`sed -e 's/^"//' -e 's/"$//' <<<"$deploy_group"`
  
sudo aws autoscaling set-desired-capacity --auto-scaling-group-name $group_trimmed --desired-capacity 2 --honor-cooldown

#sudo aws deploy create-deployment --application-name newest-cicd --deployment-group-name $group_trimmed --ignore-application-stop-failures --s3-location bundleType=tar,bucket=cicd-poc-deploy-bucket,key=myapp.tar --description "Jenkins $JOB_NAME build number $BUILD_NUMBER"

echo "Deployed $BUILD_NUMBER to $group_trimmed"

