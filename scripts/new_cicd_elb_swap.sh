#!/bin/bash
env -i
set -ex


##### Find the correct ASG #####
group_counter=0
# Loop through all existing AutoScaling Groups
while [[ `sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter ] .AutoScalingGroupName"` != null ]]; do
  # Determine whether the ASG name corresponds with the correct app name
  if [[ `sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter ] .Tags[0] .ResourceId"` == *"cicd"* ]]; then
    # Determine whether the ASG is attached to an ELB
    if [[ `sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter ] .LoadBalancerNames"` == "[]" ]]; then
      # If the ASG is not attached to the ELB, set the deploy group to it
      deploy_group=`sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter ] .AutoScalingGroupName"`
      remove_group=`sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter + 1 ] .AutoScalingGroupName"`
      echo "Deploy group is: $deploy_group and Remove group is: $remove_group"
      # Set the ASG that is currently attached 
    elif [[ `sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter ] .LoadBalancerNames"` > 2 ]]; then
      remove_group=`sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter ] .AutoScalingGroupName"`
      deploy_group=`sudo aws autoscaling describe-auto-scaling-groups | jq -r ".AutoScalingGroups[ $group_counter -1 ] .AutoScalingGroupName"`
      echo "Deploy group is: $deploy_group and Remove group is: $remove_group."
           
    else
      # If the ASG is attached to the ELB, do not proceed and tell the user
      echo "No ASGs match your deployment."
      exit 1
    fi
  fi
  let "group_counter += 1"
done

##### Get the number of instances in the ASG #####
getInstanceNum () {
  instance_counter=0

  until [[ -z `sudo aws ec2 describe-instances --filter "Name=tag:aws:autoscaling:groupName,Values='$1'" --query "Reservations[*].Instances[ $instance_counter ].[InstanceId]" --output text` ]]
  do
    let "instance_counter += 1"
  done

  echo $instance_counter
}

##### Get the desired capacity of the ASG #####
getDesiredCapacity () {
  
  des_cap=`sudo aws autoscaling describe-auto-scaling-groups --auto-scaling-group-name $1 | jq '.AutoScalingGroups[0] .DesiredCapacity'`

  echo $des_cap
}



desired_capacity=$(getDesiredCapacity $deploy_group)
echo "desired capacity: $desired_capacity"

instance_num=$(getInstanceNum $deploy_group)
echo "instances: $instance_num"

##### If the desired capacity has been met in the ASG #####
if [[ $instance_num == $desired_capacity ]]; then

  # Attach the "green" ASG to the ELB
  sudo aws autoscaling attach-load-balancers --load-balancer-names classic-elb --auto-scaling-group-name $deploy_group
  
  # Set desired capacity on "blue" ASG to 0
  sudo aws autoscaling set-desired-capacity --auto-scaling-group-name $remove_group --desired-capacity 0 --honor-cooldown
  
  # Tell the user what will happen with the ASGs
  echo "$deploy_group has been added to ELB"
  echo "$remove_group will start terminating instances immediately and will be removed from ELB in 10 minutes"

  
  # Wait 10 minutes and then terminate the ASG. I should run integration tests here to determine whether I should scale down ASG or not.
  sleep 10m
  sudo aws autoscaling detach-load-balancers --auto-scaling-group-name $remove_group --load-balancer-names classic-elb
  echo "$remove_group has been detached from classic-elb"
  
else
  # If the desired capacity has NOT been met in the ASG
  echo "AutoScalingGroup $deploy_group is not ready to take over traffic from $remove_group"
  exit 1
fi 
  

  

