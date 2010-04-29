if ARGV.size < 1
  puts 'Usage: java -jar jruby-complete-1.4.1.jar node_info_collector.rb NODE_IP_ADDRESS_1 NODE_IP_ADDRESS_2 ...'
  exit 1
end

ip_addresses = ARGV
nodes = {}

require 'java'

TOMCAT = '/opt/abiquo-server/tomcat'
NODE_COLLECTOR = "#{TOMCAT}/webapps/nodecollector/WEB-INF"

Dir.glob("#{TOMCAT}/lib/*jar").each { |jar| require jar }
Dir.glob("#{NODE_COLLECTOR}/lib/*.jar").each { |jar| require jar }
JRuby.runtime.jruby_class_loader.addURL(java.io.File.new("#{NODE_COLLECTOR}/classes").to_url)

import org.springframework.context.support.ClassPathXmlApplicationContext

app_context = ClassPathXmlApplicationContext.new("file:" + File.expand_path("#{NODE_COLLECTOR}/springresources/applicationcontext.xml"))

host_resource = app_context.get_bean('hostResource')
virtual_system_resource = app_context.get_bean('virtualSystemResource')

ip_addresses.each do |ip_address|
  node_info = {
    :hypervisor => {},
    :virtual_system => []
  }
  virtual_system_resource.ip_address = ip_address
  host_resource.ip_address = ip_address

  host_info = host_resource.host_info
  node_info[:hypervisor][:name] = host_info.hypervisor.name
  node_info[:hypervisor][:version] = host_info.version

  virtual_system_resource.list_virtual_systems.vs.each do |vs|
    vs_info = {
      :uuid => vs.uuid,
      :port => vs.vport,
      :status => vs.status.name,
      :disks => []
    }
    vs.disks.each do |disk|
      vs_info[:disks] << {
        :hd => disk.hd_value,
        :image => disk.image_path,
        :type => disk.disk_type.name,
        :format => disk.disk_format_type.name
      }
    end

    node_info[:virtual_system] << vs_info
  end

  nodes[ip_address] = node_info
end


puts "\n** System information collected:\n\n"
nodes.each do |ip_address, node_info|
  puts "* #{ip_address}"
  puts "\n\t+ hypervisor:"
  puts "\t\t- name: #{node_info[:hypervisor ][:name]}"
  puts "\t\t- version: #{node_info[:hypervisor ][:version]}"
  puts "\n\t+ virtual systems:"
  node_info[:virtual_system].each do |vs|
    puts "\t\t- uuid: #{vs[:uuid]}"
    puts "\t\t- port: #{vs[:port]}"
    puts "\t\t- status: #{vs[:status]}"
    puts "\t\t- disks:"
    vs[:disks].each do |disk|
      puts "\t\t\t· hd: #{disk[:hd]}"
      puts "\t\t\t· image path: #{disk[:image]}"
      puts "\t\t\t· disk type: #{disk[:type]}"
      puts "\t\t\t· disk format: #{disk[:format]}"
      puts "\n"
    end
    puts "\n"
  end
end
