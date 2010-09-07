#
# Cookbook Name:: ec2-ebs
# Recipe:: default
#
# Assumes volumes are preformatted by YOU or specified as
# # in cluster:
# server :log_a, :zone => :eu_west_1a, :disk => {:sdf => ["vol-abcd1234", :format]}
# # in chef_dna:
# :ebs_volumes => [
#   {:device => "sdf", :path => "/apps", :format => format_disk_on_device?("sdf")}
# ],


for ebs_volume in (node["ebs_volumes"] || [])
  if (`grep /dev/#{ebs_volume[:device]} /etc/fstab` == "")
    while not File.exists?("/dev/#{ebs_volume[:device]}")
      Chef::Log.info("EBS volume device /dev/#{ebs_volume[:device]} not ready...")
      sleep 5 
    end

    execute "format #{ebs_volume[:device]}" do
      command "mkfs -t ext3 -F /dev/#{ebs_volume[:device]}"
      only_if { ebs_volume[:format] }
    end

    directory ebs_volume[:path] do
      owner 'root'
      group 'root'
      mode 0755
    end
  
    mount ebs_volume[:path] do
      device "/dev/#{ebs_volume[:device]}"
      fstype "ext3"
      action [:mount, :enable]
    end
  end
end
