require 'chef/provisioning/aws_driver/aws_rds_resource'
require 'chef/provisioning/aws_driver/aws_taggable'

# http://docs.aws.amazon.com/sdkforruby/api/Aws/RDS/DBCluster.html
class Chef::Resource::AwsRdsCluster < Chef::Provisioning::AWSDriver::AWSRDSResource
  include Chef::Provisioning::AWSDriver::AWSTaggable

  aws_sdk_type ::Aws::RDS::DBCluster, id: :db_cluster_identifier

  ## first class attributes for RDS parameters
  # req
  attribute :db_cluster_identifier, kind_of: String, name_attribute: true
  # req
  attribute :engine, kind_of: String
  # not req for api, but required for this.
  attribute :master_username, kind_of: String
  attribute :master_user_password, kind_of: String
  # not req
  attribute :engine_version, kind_of: String
  attribute :port, kind_of: Integer
  # We cannot pass the resource or an AWS object because there is no AWS model
  # and that causes lookup_options to fail
  attribute :db_subnet_group_name, kind_of: String
  # We cannot pass the resource or an AWS object because there is no AWS model
  # and that causes lookup_options to fail
  attribute :db_cluster_parameter_group_name, kind_of: String

  attribute :vpc_security_group_ids, kind_of: Array

  attribute :backup_retention_period, kind_of: Integer, :default => nil
  attribute :preferred_backup_window, kind_of: String, :default => nil
  attribute :preferred_maintenance_window, kind_of: String, :default => nil

  attribute :database_name, :kind_of => String, :default => nil



  # RDS has a ton of options, allow users to set any of them via a
  # custom Hash
  attribute :additional_options, kind_of: Hash, default: {}

  ## aws_rds_cluster specific attributes
  ##the existing state
  ### wait for create is BROKEN
  attribute :wait_for_create, kind_of: [TrueClass, FalseClass], default: false
  attribute :wait_for_delete, kind_of: [TrueClass, FalseClass], default: true
  #and new - wait for update by default
  attribute :wait_for_update, kind_of: [TrueClass, FalseClass], default: true
  # when we wait - how times we retry and how long we sleep between retries
  # this is long by default because a lot of modifications, ie instance up/downgrade, take a long time.
  attribute :wait_time, kind_of: Integer, default: 10
  attribute :wait_tries, kind_of: Integer, default: 600

  attribute :skip_final_snapshot, kind_of: [TrueClass, FalseClass], default: true

  def aws_object
    begin
      result = self.driver.rds_resource.db_cluster(db_cluster_identifier)
      return nil unless result && result.status != 'deleting'
      result
    rescue ::Aws::RDS::Errors::DBClusterNotFoundFault  #this rescue applies to result.status, not result= which doesnt error
      nil
    end
  end

  def status
    begin
      aws_object.status if aws_object
    rescue ::Aws::RDS::Errors::DBClusterNotFoundFault
      nil
    end
  end

  def rds_tagging_type
    "db"
  end
end
