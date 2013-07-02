#!/usr/bin/ruby
require 'rpm'
require 'fileutils'
require 'trollop'
require 'io/console'
require 'json'




# Get command line opts

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

# Read the repos we want to sync in
channels = JSON.parse( IO.read(opts[:config]))


# A quick method to read in a password
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

# Read in the password from the console
if opts[:password]
  password = opts[:password]
else
  password = get_password("Enter your password:  ")
end
  
# Create a new channels folder
Dir.mkdir("channels") unless File.exists?("channels")             


# Loop over each of the defined channels
channels.each {
  |channelname,value|
  rpms = Hash.new
  puts "Downloading channel #{channelname}"
  Dir.mkdir("channels/#{channelname}") unless File.exists?("channels/#{channelname}")   
  # Loop over each member repository of a channel
  value['repositories'].each  {
    |name,url|            
    puts "Synchronising repo #{name} from #{url}"
    Dir.mkdir("channels/#{channelname}/#{name}") unless File.exists?("channels/#{channelname}/#{name}")  
    # Run wget to mirror the folder
    system "wget -nv -N -nd  -r -l 1 #{url} -P channels/#{channelname}/#{name}"
    rpmfiles = Dir["channels/#{channelname}/#{name}/*.rpm"]
    # Create a hash of versions of each package
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
    # Sort our array of version numbers
    rpmsort = array.sort
    selectedrpm = ""
    newestversion = RPM::Version.new("0.0.0")
    array.each {
    |rpmfile|
       pkg = RPM::Package.open(rpmfile)        
       if pkg.version > newestversion
        newestversion = pkg.version
        selectedrpm = rpmfile
       end
    }
    filename = File.basename(selectedrpm)
    FileUtils.cp selectedrpm, "channels/#{channelname}/selected/#{filename}"
  }  
}

channels.each {
  |channelname,value|
  system "rhnpush --force -p#{password} -dchannels/#{channelname}/selected --channel #{channelname} -u #{opts[:username]} --server #{opts[:server]}"
}