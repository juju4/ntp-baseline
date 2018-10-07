# encoding: utf-8

# copyright: 2015, The Authors
# license: All rights reserved

ntp_package = attribute('ntp_package', default: 'openntpd', description: 'Check which ntp package is used: ntpd, openntpd...')
ntp_servers = attribute(
  'ntp_servers',
  default: [
    "pool.ntp.org"
  ],
  description: 'list of ntp servers to use'
)

if "#{ntp_package}" == 'ntpd'
  ntp_service = 'ntpd'
  ntp_bin = '/usr/sbin/ntpd'
  ntp_drift_mode = '0640'
  if os.darwin?
    ntp_conf = '/private/etc/ntp-restrict.conf'
    ntp_user = 'root'
    ntp_drift = '/var/db/ntp.drift'
    ntp_drift_mode = '0644'
  elsif os.redhat?
    ntp_conf = '/etc/ntp.conf'
    ntp_user = 'root'
    ntp_drift = '/var/ntp/drift/ntp.drift'
  elsif os.debian?
    ntp_user = 'ntp'
    ntp_conf = '/var/lib/ntp/drift'
  end
elsif "#{ntp_package}" == 'openntpd'
  ntp_conf = '/etc/openntpd/ntpd.conf'
  ntp_user = 'ntpd'
  ntp_service = 'openntpd'
  ntp_bin = '/usr/sbin/openntpd'
  ntp_drift = '/var/lib/openntpd/db/ntpd.drift'
  ntp_drift_mode = '0644'
end

title 'ntp section'

control 'ntp-1.0' do                        # A unique ID for this control
  impact 0.7                                # The criticality, if this control fails.
  title 'ntpd should be present'
  desc 'Ensure ntpd executable and configuration are present'
  if "#{ntp_package}" == 'ntpd' and os.darwin?
    describe file("#{ntp_conf}") do
      it { should be_file }
      its('content') { should match(/restrict default (kod nomodify notrap nopeer noquery|ignore)/) }
      its('content') { should match 'includefile /private/etc/ntp.conf' }
    end
  elsif "#{ntp_package}" == 'ntpd'
    describe file("#{ntp_conf}") do
      it { should be_file }
      its('content') { should match(/^disable monitor/) }
      its('content') { should match(/^(restrict default ignore|restrict -4 default ignore|restrict -4 default kod notrap nomodify nopeer noquery limited)/) }
      its('content') { should match(/^(restrict -6 default ignore|restrict -6 default kod notrap nomodify nopeer noquery limited)/) }
      its('content') { should match(/^restrict 127.0.0.1/) }
      its('content') { should match(/^(restrict -6 ::1|restrict ::1)/) }
      ntp_servers.each do |server|
        its('content') { should match(/^server #{server}/) }
        its('content') { should match(/^restrict #{server} default.*nomodify (notrap nopeer|nopeer notrap) noquery/) }
      end
    end
    describe command("ntpstat") do
      its('stdout') { should match 'synchronised to' }
      its('stderr') { should eq '' }
      its('exit_status') { should eq 0 }
    end
    describe command("timedatectl status") do
      its('stdout') { should match 'NTP enabled: yes' }
      its('stdout') { should match 'NTP synchronized: yes' }
      its('stderr') { should eq '' }
      its('exit_status') { should eq 0 }
    end
  elsif "#{ntp_package}" == 'openntpd'
    describe file("#{ntp_conf}") do
      it { should be_file }
      its('content') { should match(/^listen on 127.0.0.1/) }
      ntp_servers.each do |server|
        its('content') { should match(/^servers #{server}/) }
      end
    end
    describe command("#{ntp_bin} -n") do
      its('stdout') { should eq '' }
      its('stderr') { should eq 'configuration OK' }
      its('exit_status') { should eq 0 }
    end
  else
    describe package("#{ntp_package}") do
      it { should be_installed }
    end
    describe service("#{ntp_service}") do
      it { should_not be_enabled }
      it { should_not be_installed }
      it { should_not be_running }
    end
  end
  describe file("#{ntp_bin}") do
    it { should be_file }
    it { should be_executable }
    it { should be_owned_by 'root' }
  end
end

control 'ntp-2.0' do
  impact 0.7
  title 'ntpd should be running'
  desc 'Ensure ntpd is running'
  only_if { !(virtualization.role == 'guest' && virtualization.system == 'docker') }
  describe processes("#{ntp_service}") do
    its('users') { should eq ["#{ntp_user}"] }
    its('list.length') { should eq 1 }
  end
end

control 'ntp-3.0' do
  impact 0.7
  title 'ntpd should have drift file'
  desc 'Ensure ntpd drift file is present'
  only_if { !(virtualization.role == 'guest' && virtualization.system == 'docker') }
  describe file("#{ntp_drift}") do
    it { should be_file }
    it { should be_owned_by "#{ntp_user}" }
    its('mode') { should cmp "#{ntp_drift_mode}" }
  end
end

control 'ntp-4.0' do
  impact 0.7
  title 'ntpd updated drift files'
  desc 'Ensure ntpd drift file is updated and less than 8h in the past'
  only_if { !(virtualization.role == 'guest' && virtualization.system == 'docker') }
  describe file("#{ntp_drift}").mtime.to_i do
    it { should <= Time.now.to_i }
    it { should >= Time.now.to_i - 28800 }
  end
end
