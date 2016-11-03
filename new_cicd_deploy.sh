#!/bin/bash
env -i
set -ex

group_counter=0
# Loop through all existing AutoScaling Groups
while [[ `sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter ] .AutoScalingGroupName"` != null ]]; do
  # Determine whether the ASG name corresponds with the correct app name
  if [[ `sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter ] .Tags[0] .ResourceId"` == *"green"* ]]; then
    # Determine whether the ASG is attached to an ELB
    if [[ `sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter ] .LoadBalancerNames"` == "[]" ]]; then
      # If the ASG is not attached to the ELB, set the deploy group to it
      deploy_group=`sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter ] .AutoScalingGroupName"`
      # Change the desired capacity of the ASG to facilitate the creation of the instances and deployment of new code
      sudo aws autoscaling set-desired-capacity --auto-scaling-group-name $deploy_group --desired-capacity 2 --honor-cooldown
      echo "Deployed $BUILD_NUMBER to $deploy_group"
    else
      # If the ASG is attached to the ELB, do not proceed and tell the user
      echo "No ASGs match your deployment."
      exit 1
    fi
  fi
  let "group_counter += 1"
done

