#!/bin/bash
env -i
set -e

# Determine which group doesn't have an ELB attached. How do I do this with a ton of ASGs?
cmd=`sudo aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[0] .LoadBalancerNames'`
  
# Get the ASG that is attached to the ELB
if [[ $cmd == '[]' ]]; then
    remove_group=$(bash -c "sudo aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[1] .AutoScalingGroupName'")
    deploy_group=$(bash -c "sudo aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[0] .AutoScalingGroupName'")
else
    remove_group=$(bash -c "sudo aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[0] .AutoScalingGroupName'")
    deploy_group=$(bash -c "sudo aws autoscaling describe-auto-scaling-groups | jq '.AutoScalingGroups[1] .AutoScalingGroupName'")
fi
remove_group_trimmed=`sed -e 's/^"//' -e 's/"$//' <<<"$remove_group"`
deploy_group_trimmed=`sed -e 's/^"//' -e 's/"$//' <<<"$deploy_group"`  

# Get the number of instances in the ASG
getInstanceNum () {
  instance_counter=0

  until [[ -z `sudo aws ec2 describe-instances --filter "Name=tag:aws:autoscaling:groupName,Values='$1'" --query "Reservations[*].Instances[ $instance_counter ].[InstanceId]" --output text` ]]
  do
    let "instance_counter += 1"
  done

  echo $instance_counter
}

# Get the desired capacity of the ASG
getDesiredCapacity () {
  
  des_cap=`sudo aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $1 | jq '.AutoScalingGroups[0] .DesiredCapacity'`

  echo $des_cap
}

desired_capacity=$(getDesiredCapacity $deploy_group_trimmed)

instance_num=$(getInstanceNum $deploy_group_trimmed)

# If the desired capacity has been met in the ASG
if [[ $instance_num == $desired_capacity ]]; then

  id_counter=0
 
  until [[ $id_counter == $desired_capacity ]]
  do
    # Set all existing instances to unhealthy and drain connections
    instance_id=`sudo aws elb describe-load-balancers --query "LoadBalancerDescriptions[*].Instances[ $id_counter ].InstanceId" --output text`
    `sudo aws autoscaling set-instance-health --instance-id $instance_id --health-status Unhealthy`
    let "id_counter += 1"
  done
  
  # Attach the ASG that we deployed to the ELB, remove the "blue" ASG from the ELB  
  sudo aws autoscaling attach-load-balancers --load-balancer-names classic-elb --auto-scaling-group-name $deploy_group_trimmed
  sudo aws autoscaling detach-load-balancers --auto-scaling-group-name $remove_group_trimmed --load-balancer-names classic-elb
  sudo aws autoscaling set-desired-capacity --auto-scaling-group-name $remove_group_trimmed --desired-capacity 0 --honor-cooldown
  
  # Tell the user where groups will end up
  echo "$remove_group_trimmed will be removed from ELB"
  echo "$deploy_group_trimmed will be added to ELB"
  
else
  # If the desired capacity has NOT been met in the ASG
  echo "AutoScalingGroup $deploy_group_trimmed is not ready to take over traffic from $remove_group_trimmed"
  exit 1
fi 
  

  
