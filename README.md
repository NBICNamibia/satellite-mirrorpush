Satellite-MirrorPush
====================
This script performs a number of functions:

* It mirrors a remote repository to a local folder.
* It selects the latest RPM in the folder
* It pushes the latest RPMS to your Satellite server.

## Why do this?

Just incase you don't trust the automatic sync on the satellite server itself.
Also, future versions will allow you to create baselines to separate dev from production.


## Todo
Version selection for production channels.


## Requirements
rpm and trollop gems.


## Installation
Run:

bundle install


## Running
Edit config.json to match your channels and repos.
Run:

./satellite-mirrorpush.rb --server <servername> --username <username> --config <path to config file>