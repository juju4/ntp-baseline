# frozen_string_literal: true

# copyright: 2015, The Authors
# license: All rights reserved

ntp_package = attribute('ntp_package', default: 'openntpd', description: 'Check which ntp package is used: ntpd, openntpd...')
ntp_servers = attribute(
  'ntp_servers',
  default: [
    'pool.ntp.org'
  ],
  description: 'list of ntp servers to use'
)

if os.redhat? && os.release == '8'
  ntp_package = 'chrony'
  ntp_service = 'chronyd'
  ntp_bin = '/usr/sbin/chronyd'
  ntp_conf = '/etc/chrony.conf'
  ntp_user = 'chrony'
  ntp_drift = '/var/lib/chrony/drift'
  ntp_drift_mode = '0640'
  ntp_drift_user = 'chrony'
end

if ntp_package.to_s == 'ntp'
  ntp_service = 'ntpd'
  ntp_bin = '/usr/sbin/ntpd'
  ntp_drift_mode = '0640'
  if os.darwin?
    ntp_conf = '/private/etc/ntp-restrict.conf'
    ntp_user = 'root'
    ntp_drift = '/var/db/ntp.drift'
    ntp_drift_mode = '0644'
    ntp_drift_user = 'root'
  elsif os.redhat?
    ntp_service = 'ntpd'
    ntp_conf = '/etc/ntp.conf'
    ntp_user = 'ntp'
    ntp_drift = '/var/ntp/drift/ntp.drift'
    ntp_drift_user = 'ntp'
  elsif os.debian?
    ntp_service = 'ntp'
    ntp_conf = '/etc/ntp.conf'
    ntp_user = 'ntp'
    ntp_drift = '/var/lib/ntp/drift'
    ntp_drift_user = 'ntp'
  end
elsif ntp_package.to_s == 'openntpd'
  ntp_conf = '/etc/openntpd/ntpd.conf'
  ntp_user = 'ntpd'
  ntp_service = 'openntpd'
  ntp_bin = '/usr/sbin/openntpd'
  ntp_drift = '/var/lib/openntpd/db/ntpd.drift'
  ntp_drift_mode = '0644'
  ntp_drift_user = 'root'
end

title 'ntp section'

if ntp_package.to_s == 'ntp' && os.darwin?
  control 'ntp-1.1' do                        # A unique ID for this control
    impact 0.7                                # The criticality, if this control fails.
    title 'ntpd/darwin should be present'
    desc 'Ensure ntpd executable and configuration are present'
    describe file(ntp_conf.to_s) do
      it { should be_file }
      its('content') { should match(/restrict default (kod nomodify notrap nopeer noquery|ignore)/) }
      its('content') { should match 'includefile /private/etc/ntp.conf' }
    end
    describe package(ntp_package.to_s) do
      it { should be_installed }
    end
    describe service(ntp_service.to_s) do
      it { should be_enabled }
      it { should be_installed }
      it { should be_running }
    end
    describe file(ntp_bin.to_s) do
      it { should be_file }
      it { should be_executable }
      it { should be_owned_by 'root' }
    end
  end
elsif ntp_package.to_s == 'ntp'
  control 'ntp-1.2' do
    impact 0.7
    title 'ntpd should be present'
    desc 'Ensure ntpd executable and configuration are present'
    describe file(ntp_conf.to_s) do
      it { should be_file }
      its('content') { should match(/^disable monitor/) }
      its('content') { should match(/^(restrict default ignore|restrict -4 default ignore|restrict -4 default kod notrap nomodify nopeer noquery limited)/) }
      its('content') { should match(/^(restrict -6 default ignore|restrict -6 default kod notrap nomodify nopeer noquery limited)/) }
      its('content') { should match(/^restrict 127.0.0.1/) }
      its('content') { should match(/^(restrict -6 ::1|restrict ::1)/) }
    end
    describe package(ntp_package.to_s) do
      it { should be_installed }
    end
    describe service(ntp_service.to_s) do
      it { should be_enabled }
      it { should be_installed }
      it { should be_running }
    end
    describe file(ntp_bin.to_s) do
      it { should be_file }
      it { should be_executable }
      it { should be_owned_by 'root' }
    end
  end
elsif ntp_package.to_s == 'openntpd'
  control 'ntp-1.3' do
    impact 0.7
    title 'openntpd should be present'
    desc 'Ensure openntpd executable and configuration are present'
    describe file(ntp_conf.to_s) do
      it { should be_file }
      its('content') { should_not match(/^listen on 127.0.0.1/) }
      ntp_servers.each do |server|
        its('content') { should match(/^servers #{server}/) }
      end
    end
    describe package(ntp_package.to_s) do
      it { should be_installed }
    end
    describe service(ntp_service.to_s) do
      it { should be_enabled }
      it { should be_installed }
      it { should be_running }
    end
    describe file(ntp_bin.to_s) do
      it { should be_file }
      it { should be_executable }
      it { should be_owned_by 'root' }
    end
  end
elsif ntp_package.to_s == 'chrony'
  control 'ntp-1.2' do
    impact 0.7
    title 'chrony should be present'
    desc 'Ensure chronyd executable and configuration are present'
    describe file(ntp_conf.to_s) do
      it { should be_file }
      its('content') { should match(/^local stratum/) }
      ntp_servers.each do |server|
        its('content') { should match(/^server #{server}/) }
      end
    end
    describe package(ntp_package.to_s) do
      it { should be_installed }
    end
    describe service(ntp_service.to_s) do
      it { should be_enabled }
      it { should be_installed }
      it { should be_running }
    end
    describe file(ntp_bin.to_s) do
      it { should be_file }
      it { should be_executable }
      it { should be_owned_by 'root' }
    end
  end
end

if ntp_package.to_s == 'ntp'
  control 'ntp-2.1' do
    impact 0.7
    title 'ntpd configuration should be valid'
    desc 'Ensure ntpd configuration is correct'
    describe command('ntpstat') do
      its('stdout') { should match 'synchronised to' }
      its('stderr') { should eq '' }
      its('exit_status') { should eq 0 }
    end
    describe command('timedatectl status') do
      its('stdout') { should match 'NTP enabled: yes' }
      its('stdout') { should match 'NTP synchronized: yes' }
      its('stderr') { should eq '' }
      its('exit_status') { should eq 0 }
    end
  end
elsif ntp_package.to_s == 'chrony'
  control 'ntp-2.2' do
    impact 0.7
    title 'chrony configuration should be valid'
    desc 'Ensure chrony configuration is correct'
    describe command('ntpstat') do
      its('stdout') { should match 'synchronised to' }
      its('stderr') { should eq '' }
      its('exit_status') { should eq 0 }
    end
    describe command('chronyc -n tracking') do
      its('stdout') { should match 'Reference ID' }
      its('stdout') { should match 'Leap status     : Normal' }
      its('stderr') { should eq '' }
      its('exit_status') { should eq 0 }
    end
    describe command('timedatectl status') do
      its('stdout') { should match 'NTP enabled: yes' }
      its('stdout') { should match 'NTP synchronized: yes' }
      its('stderr') { should eq '' }
      its('exit_status') { should eq 0 }
    end
  end
elsif ntp_package.to_s == 'openntpd'
  control 'ntp-2.3' do
    impact 0.7
    title 'openntpd configuration should be valid'
    desc 'Ensure opentpd configuration is correct'
    describe command("#{ntp_bin} -n") do
      its('stdout') { should eq '' }
      its('stderr') { should eq 'configuration OK' }
      its('exit_status') { should eq 0 }
    end
  end
end

control 'ntp-2.0' do
  impact 0.7
  title 'ntpd should be running'
  desc 'Ensure ntpd is running'
  only_if { !(virtualization.role == 'guest' && (virtualization.system == 'docker' || virtualization.system == 'lxd')) }
  describe processes(ntp_service.to_s) do
    its('users') { should eq [ntp_user.to_s] }
    its('list.length') { should eq 1 }
  end
end

control 'ntp-3.0' do
  impact 0.7
  title 'ntpd should have drift file'
  desc 'Ensure ntpd drift file is present'
  only_if { !(virtualization.role == 'guest' && (virtualization.system == 'docker' || virtualization.system == 'lxd')) }
  describe file(ntp_drift.to_s) do
    it { should be_file }
    it { should be_owned_by ntp_drift_user.to_s }
    its('mode') { should cmp ntp_drift_mode.to_s }
  end
end

control 'ntp-4.0' do
  impact 0.7
  title 'ntpd updated drift files'
  desc 'Ensure ntpd drift file is updated and less than 8h in the past'
  only_if { !(virtualization.role == 'guest' && (virtualization.system == 'docker' || virtualization.system == 'lxd')) }
  describe file(ntp_drift.to_s).mtime.to_i do
    it { should <= Time.now.to_i }
    it { should >= Time.now.to_i - 28800 }
  end
end
