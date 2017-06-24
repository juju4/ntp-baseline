# encoding: utf-8
# copyright: 2015, The Authors
# license: All rights reserved

title 'ntp section'


control 'ntp-1.0' do                        # A unique ID for this control
  impact 0.7                                # The criticality, if this control fails.
  title 'ntpd should be present'
  desc 'Ensure ntpd executable and configuration are present'
  if os.darwin?
    describe file('/private/etc/ntp-restrict.conf') do
      it { should be_file }
      its('content') { should match 'restrict default kod nomodify notrap nopeer noquery' }
      its('content') { should match 'includefile /private/etc/ntp.conf' }
    end
  elsif os.redhat?
    describe file('/etc/ntp.conf') do
      it { should be_file }
      its('content') { should match 'restrict default nomodify nopeer notrap noquery' }
    end
  else
    describe file('/etc/ntp.conf') do
      it { should be_file }
      its('content') { should match 'restrict default kod nomodify nopeer notrap noquery' }
    end
  end
  describe file('/usr/sbin/ntpd') do
    it { should be_file }
    it { should be_executable }
    it { should be_owned_by 'root' }
  end
end

control 'ntp-2.0' do
  impact 0.7
  title 'ntpd should be running'
  desc 'Ensure ntpd is running'
  if os.darwin?
    describe processes('ntpd') do
      its('users') { should eq ['root'] }
      its('list.length') { should eq 1 }
    end
  else
    describe processes('ntpd') do
      its('users') { should eq ['ntp'] }
      its('list.length') { should eq 1 }
    end
  end
end

control 'ntp-3.0' do
  impact 0.7
  title 'ntpd should have drift file'
  desc 'Ensure ntpd drift file is present'
  if os.darwin?
    describe file('/var/db/ntp.drift') do
      it { should be_file }
      it { should be_owned_by 'root' }
      its('mode') { should cmp '0644' }
    end
  elsif os.redhat?
    describe file('/var/lib/ntp/drift') do
      it { should be_file }
      it { should be_owned_by 'ntp' }
      its('mode') { should cmp '0640' }
    end
  else
    describe file('/var/ntp/drift/ntp.drift') do
      it { should be_file }
      it { should be_owned_by 'ntp' }
      its('mode') { should cmp '0640' }
    end
  end
end

control 'ntp-4.0' do
  impact 0.7
  title 'ntpd updated log files'
  desc 'Ensure ntpd drift file is updated and less than 4h in the past'
  describe file('/var/log/system.log').mtime.to_i do
    it { should <= Time.now.to_i }
    it { should >= Time.now.to_i - 14400}
  end
end

