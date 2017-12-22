require 'chef/provisioning/aws_driver/aws_provider'
require 'chef/provisioning/aws_driver/tagging_strategy/rds'

# http://docs.aws.amazon.com/sdkforruby/api/Aws/RDS/DBCluster.html
class Chef::Provider::AwsRdsCluster < Chef::Provisioning::AWSDriver::AWSProvider
  include Chef::Provisioning::AWSDriver::TaggingStrategy::RDSConvergeTags

  provides :aws_rds_cluster

  ## any new first class attributes that should be passed to rds MUST BE added here.
  ## these are used to assemble options_hash
  ## anything in additional_options is pashed into options_hash on it's own
  REQUIRED_OPTIONS = %i(db_cluster_identifier engine
                        master_username master_user_password)

  OTHER_OPTIONS = %i(engine_version port db_subnet_group_name db_cluster_parameter_group_name vpc_security_group_ids backup_retention_period preferred_backup_window preferred_maintenance_window database_name)


# ## update (and therefor modify) will ALWAYS called on any run after a create
# ## there's no sane ability to compare desired state vs current state without extensive per-option logic
# ## calling modify (even with/without apply_immediately) is safe - it only
# ## "updates" the master password (modify has know way to determine the previous
# ## one, of course), which is effectively a non-op.
  def update_aws_object(cluster)
    # TODO
    ### these options need to be transformed...this could get hairy?
    ### create and modify use different names for them.
    ### and re-naming an cluster could definitely get weird.
    # db_cluster_identifier - create
    # new_db_cluster_identifier - modify


    ## remove create specific options we can't pass to modify
    [:engine, :engine_version, :master_username, :db_subnet_group_name, :availability_zones, :character_set_name, :database_name, :kms_key_id, :pre_signed_url, :destination_region, :source_region, :storage_encrypted, :tags].each do |key|
      options_hash.delete(key)
    end

    ## always wait for a safe state (available) before we try to apply a modification.
    wait_for(
      aws_object: cluster,
      query_method: :status,
      expected_responses: ['available'],
      tries: new_resource.wait_tries,
      sleep: new_resource.wait_time
    ) { |cluster|
      cluster.reload
      Chef::Log.info "Update RDS cluster: before update, waiting for #{new_resource.db_cluster_identifier} to be available.  State: #{cluster.status} - pending: #{cluster.pending_modified_values.to_h}" if cluster.status != "available"
    }

    updated={} #so we can use this outside the converge_by
    converge_by "update RDS cluster #{new_resource.db_cluster_identifier} in #{region}" do
      updated=new_resource.driver.rds_client.modify_db_cluster(options_hash).to_h[:db_cluster]
    end

    if new_resource.wait_for_update
      slept=false
      ## use the response from modify to determine if we applied an update we should wait for
      updated[:pending_modified_values].each do |k, v|
        ## we ALWAYS apply an update, but we dont need to "wait" for the master_user_password (or do we?)
        if k.to_s != "master_user_password"
          if ! slept  #maybe we should just break the loop?
            Chef::Log.info "Updated RDS cluster: #{new_resource.db_cluster_identifier}, sleeping #{new_resource.wait_time} seconds to verify state is now available due to #{updated[:pending_modified_values]}"
            sleep new_resource.wait_time  #it takes a few seconds before the cluster goes out of 'available'
            slept=true
          end
          converge_by "waiting until RDS cluster is available after update  #{new_resource.db_cluster_identifier} in #{region}" do
            wait_for(
              aws_object: cluster,
              query_method: :status,
              expected_responses: ['available'],
              tries: new_resource.wait_tries,
              sleep: new_resource.wait_time
            ) { |cluster|
              cluster.reload
              Chef::Log.info "Update RDS cluster, waiting for #{new_resource.db_cluster_identifier} to be available. State: #{cluster.status} - pending: #{cluster.pending_modified_values.to_h}"
            }
          end
        end
      end if updated[:pending_modified_values]
    end

  end #def update

  def create_aws_object

    ## remove modify specific options we can't pass to create
    [:apply_immediately, :allow_major_version_upgrade, :ca_certificate_identifier ].each do |key|
      options_hash.delete(key)
    end
    Chef::Log.info "Create RDS cluster: #{new_resource.db_cluster_identifier}"
    cluster={}
    converge_by "create RDS cluster #{new_resource.db_cluster_identifier} in #{region}" do
      cluster=new_resource.driver.rds_resource.create_db_cluster(options_hash)
    end

    if new_resource.wait_for_create
      ## TODO
      Chef::Log.warn("Skipping RDS cluster wait_for_create because it's broken")
# #TODO:  wait for create is BROKEN.
#       converge_by "waiting until RDS cluster is available after create  #{new_resource.db_cluster_identifier} in #{region}" do

#         ## custom wait loop - we can't use wait_for because we want to check for multiple possibilities, and some of them are undef at the time we start the loop.
#         ## wait for:
#         ##   endpoint address to be available - at this point, the cluster is typically usable. we get access to the cluster a good 1000+s earlier than we would waiting for available.
#         ##   available or backing-up states, just in case we can't/dont get an endpoint address for some reason.
#         #just in case - sometimes cluster is still nil when we get here, so avoid error cases
#         tries = 10
# sleep 10
# ### ok this doesnt work
# # this cluster object is never updating.
#         p "dsr: trying aws_object..."
#         while cluster.nil?
#         # while new_resource.aws_object.nil?
#           sleep 10
#           ## cant reload this, it's nil.
#           # cluster.reload
#           tries -= 1
#           ## dont raise, 10 10 second sleeps is not enough for a cluster create
#           #Chef::Log.info
#           p "dsr: waiting for #{new_resource.db_cluster_identifier} cluster object to become non-nil, something failed with #{tries} remaining.  cluster: #{cluster}, new_resource.aws_object #{new_resource.aws_object}"#  if tries < 0

#       # cluster=new_resource.driver.rds_resource.db_cluster(new_resource.db_cluster_identifier)
#           # p "dsr: new_resource.driver.rds_resource.db_cluster(new_resource.db_cluster_identifier): #{new_resource.driver.rds_resource.db_cluster(new_resource.db_cluster_identifier)}"
#           # p "dsr: new_resource.aws_object.status #{new_resource.aws_object.status}"


#           # raise "timed out waiting for #{new_resource.db_cluster_identifier} cluster object to become non-nil, something failed with #{tries} remaining.  cluster: #{cluster}" if tries < 0
#         end
#         tries = new_resource.wait_tries
#         while defined?(cluster.endpoint).nil? \
#          or defined?(cluster.endpoint.address).nil? \
#          or cluster.status.to_s == 'available' \
#          or cluster.status.to_s == 'backing-up'
#           cluster.reload  #reload first so we get a useful final log
#           Chef::Log.info "Create RDS cluster: waiting for #{new_resource.db_cluster_identifier} to be available. Tries remaining: #{tries} State: #{cluster.status}, pending modifications: #{cluster.pending_modified_values.to_h}, endpoint: #{cluster.endpoint.to_h if ! cluster.endpoint.nil? }"
#           sleep new_resource.wait_time
#           tries -= 1
#           raise StatusTimeoutError.new(cluster, cluster.status, "endpoint available, 'available', or 'backing-up'") if tries < 0
#         end
#         Chef::Log.info "Create RDS cluster:  #{new_resource.db_cluster_identifier} endpoint address = #{cluster.endpoint.address}:#{cluster.endpoint.port}"
#       end
    end # end wait?
  end #def create

  def destroy_aws_object(cluster)
    ### No need to wait before destroy - destroy doesnt require an available/etc state.
    converge_by "delete RDS cluster #{new_resource.db_cluster_identifier} in #{region}" do
      cluster.delete(skip_final_snapshot: new_resource.skip_final_snapshot)
    end
    if new_resource.wait_for_delete
      # Wait up to sleep * tries / 60 minutes for the db cluster to shutdown
      converge_by "waited until RDS cluster #{new_resource.db_cluster_identifier} was deleted" do
        wait_for(
          aws_object: cluster,
          # http://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBcluster.Status.html
          # It cannot _actually_ return a deleted status, we're just looking for the error
          query_method: :status,
          expected_responses: ['deleted'],
          acceptable_errors: [::Aws::RDS::Errors::DBClusterNotFoundFault],
          tries: new_resource.wait_tries,
          sleep: new_resource.wait_time
        ) { |cluster|
            cluster.reload
            Chef::Log.info "Delete RDS cluster: waiting for #{new_resource.db_cluster_identifier} to be deleted.  State: #{cluster.status}"
       }
      end
    end
  end #def destroy


  # Sets the additional options then overrides it with all required options from
  # the resource as well as optional options
  def options_hash
    @options_hash ||= begin
      opts = Hash[new_resource.additional_options.map{|(k,v)| [k.to_sym,v]}]
      REQUIRED_OPTIONS.each do |opt|
        opts[opt] = new_resource.send(opt)
      end
      OTHER_OPTIONS.each do |opt|
        opts[opt] = new_resource.send(opt) if ! new_resource.send(opt).nil?
      end
      AWSResource.lookup_options(opts, resource: new_resource)
      opts
    end
  end

end

