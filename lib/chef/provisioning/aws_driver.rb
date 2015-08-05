require 'chef/provisioning'
require 'chef/provisioning/aws_driver/driver'

require "chef/resource/aws_auto_scaling_group"
require "chef/resource/aws_cache_cluster"
require "chef/resource/aws_cache_replication_group"
require "chef/resource/aws_cache_subnet_group"
require "chef/resource/aws_rds_subnet_group"
require "chef/resource/aws_dhcp_options"
require "chef/resource/aws_ebs_volume"
require "chef/resource/aws_eip_address"
require "chef/resource/aws_image"
require "chef/resource/aws_instance"
require "chef/resource/aws_internet_gateway"
require "chef/resource/aws_launch_configuration"
require "chef/resource/aws_load_balancer"
require "chef/resource/aws_network_acl"
require "chef/resource/aws_network_interface"
require "chef/resource/aws_route_table"
require "chef/resource/aws_s3_bucket"
require "chef/resource/aws_security_group"
require "chef/resource/aws_sns_topic"
require "chef/resource/aws_sqs_queue"
require "chef/resource/aws_subnet"
require "chef/resource/aws_vpc"
