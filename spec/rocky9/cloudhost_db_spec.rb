require 'spec_helper'

describe package('MariaDB-server') do
  it { should be_installed.with_version('12.3') }
end

describe package('MariaDB-client') do
  it { should be_installed }
end

describe package('MariaDB-common') do
  it { should be_installed }
end

describe service('mariadb') do
  it { should be_enabled }
  it { should be_running }
end

describe port(3306) do
  it { should be_listening }
end

# The package assertion above only proves what is on disk. This catches a
# running server that came from somewhere else -- the AppStream mariadb module,
# or an install that nexcess.mariadb's remove-then-reinstall step failed to
# clear.
describe command('mysql -u root -N -B -e "SELECT VERSION()"') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^12\.3\./) }
end

# enabled + running + listening all pass on a server whose datadir is
# unwritable or whose storage engine never initialised. DROP IF EXISTS keeps
# this repeatable when the container is kept with cleanup=false.
describe command('mysql -u root -N -B -e "DROP DATABASE IF EXISTS spec_probe; ' \
                 'CREATE DATABASE spec_probe; ' \
                 'CREATE TABLE spec_probe.t (i INT) ENGINE=InnoDB; ' \
                 'INSERT INTO spec_probe.t VALUES (42); ' \
                 'SELECT i FROM spec_probe.t; ' \
                 'DROP DATABASE spec_probe;"') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/^42$/) }
end

# nexcess.mariadb templates my.cnf.j2 to /etc/my.cnf.d/server.cnf with its
# restart handler commented out, so the file only takes effect because the
# service start happens to follow it. 512 is the role's mysql_max_connections;
# MariaDB's own default is 151.
describe command('mysql -u root -N -B -e "SELECT @@max_connections"') do
  its(:stdout) { should match(/^512$/) }
end
