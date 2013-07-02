#!/usr/bin/ruby
require 'rpm'
require 'fileutils'
require 'trollop'
require 'io/console'
require 'json'

rpms = Hash.new

opts = Trollop::options do
  opt :server, "Red Hat Satellite server", :type => :string
  opt :username, "Satellite User name", :type => :string
  opt :password, "Satellite password", :type => :string
  opt :config, "Config file", :type => :string
end

Trollop::die :server, "must exist" unless opts[:server]
Trollop::die :username, "must exist" unless opts[:username]
Trollop::die :config, "must exist" unless opts[:config]
Trollop::die :config, "must exist" unless File.exist?(opts[:config])

channels = JSON.parse( IO.read(opts[:config]))




if STDIN.respond_to?(:noecho)
  def get_password(prompt="Password: ")
    print prompt
    STDIN.noecho(&:gets).chomp
  end
else
  def get_password(prompt="Password: ")
    `read -s -p "#{prompt}" password; echo $password`.chomp
  end
end

if opts[:password]
  password = opts[:password]
else
  password = get_password("Enter your password:  ")
end
  
Dir.mkdir("channels") unless File.exists?("channels")             

channels.each {
  |channelname,value|

  puts "Downloading channel #{channelname}"
  Dir.mkdir("channels/#{channelname}") unless File.exists?("channels/#{channelname}")   
  value['repositories'].each  {
    |name,url|            
    puts "Synchronising repo #{name} from #{url}"
    Dir.mkdir("channels/#{channelname}/#{name}") unless File.exists?("channels/#{channelname}/#{name}")  
    system "wget -nv -N -nd  -r -l 1 #{url} -P channels/#{channelname}/#{name}"
    rpmfiles = Dir["channels/#{channelname}/#{name}/*.rpm"]
    rpmfiles.each {
      |f|
      pkg = RPM::Package.open(f)
      if(rpms[pkg.name])
        rpms[pkg.name] = rpms[pkg.name] << f
      else
        rpms[pkg.name] = [f]
      end 
    }
  }

  puts "Selecting newest rpms"
  Dir.mkdir("channels/#{channelname}/selected") unless File.exists?("channels/#{channelname}/selected") 
  FileUtils.rm(Dir.glob("channels/#{channelname}/selected/*.rpm"))
  
  rpms.each {
    |key,array|
    rpmsort = array.sort
    selectedrpm = (array.take(1))[0]
    filename = File.basename(selectedrpm)      
    FileUtils.cp selectedrpm, "channels/#{channelname}/selected/#{filename}"
  }

  

}

channels.each {
  |channelname,value|
  system "rhnpush --force -p#{password} -dchannels/#{channelname}/selected --channel #{channelname} -u #{opts[:username]} --server #{opts[:server]}"
}