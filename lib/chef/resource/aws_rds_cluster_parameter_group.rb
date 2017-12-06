require 'chef/provisioning/aws_driver/aws_rds_resource'
require 'chef/provisioning/aws_driver/aws_taggable'

# taken from resources/aws_rds_parameter_group.rb
# then switched to use driver.rds_resource.client instead of driver.rds to use sdkv2 instead of v1.   there are a number of notes and conditions in here that are unvalidated...
class Chef::Resource::AwsRdsClusterParameterGroup < Chef::Provisioning::AWSDriver::AWSRDSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  # there is no class for a parameter group specifically
  aws_sdk_type ::Aws::RDS

  attribute :name, kind_of: String, name_attribute: true
  attribute :db_parameter_group_family, kind_of: String, required: true
  attribute :description, kind_of: String, required: true
  attribute :parameters, kind_of: Array, default: []

  def aws_object

    ## in sdk2, this is a struct.  in sdk1 it was an object.
    object = self.driver.rds_resource.client.describe_db_cluster_parameter_groups(db_cluster_parameter_group_name: name)[:db_cluster_parameter_groups].first

    # p "dsr: initial object: #{aws_object}"
    # ## because it's a struct, I dont see a sane way to append the parameters into it
    # ## since nothing actually consume this, skip it.
    # initial_request = self.driver.rds_resource.client.describe_db_cluster_parameters(db_cluster_parameter_group_name: name, max_records: 100)
    # marker = initial_request[:marker]
    # p "dsr: initial parameters: #{initial_request[:parameters]}"
    # parameters = initial_request[:parameters]
    # while !marker.nil?
    #   more_results = self.driver.rds_resource.client.describe_db_cluster_parameters(db_cluster_parameter_group_name: name, max_records: 100, marker: marker)
    #   parameters += more_results[:parameters]
    #   marker = more_results[:marker]
    # end
    # p "dsr: final parameters: #{parameters}"

    # ## the 2.0 rds_parameter_group implementation does this:
    # ##    driver.rds.reset_db_parameter_group(db_parameter_group_name: name, parameters: parameters)
    # ## but THAT actually RESETS the group every time this is called - which is insane.  and breaks on many group state conditions.
    # object[:parameters] = parameters
    object
  # this is NOT a DBCluster error, because that's not what's returned..
  rescue ::Aws::RDS::Errors::DBParameterGroupNotFound
    nil
  end


  def rds_tagging_type
    "pg"
  end
end
