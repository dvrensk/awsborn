require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Awsborn::KnownHostsUpdater do
  describe "#get_console_fingerprint" do
    it "sets @console_finger_print" do
      Awsborn.stub!(:wait_for).and_yield
      ec2 = mock("ec2")
      fingerprint =<<-EOS
      -----BEGIN SSH HOST KEY FINGERPRINTS-----
      2048 ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff /etc/ssh/ssh_host_rsa_key.pub (RSA)
      EOS
      ec2.stub!(:get_console_output).and_return(fingerprint)

      updater = Awsborn::KnownHostsUpdater.new ec2, "localhost"
      updater.get_console_fingerprint
      updater.console_fingerprint.should == "ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff:ff"
    end
  end
end
