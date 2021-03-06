require 'faraday/restrict_ip_addresses'
require 'spec_helper'

describe Faraday::RestrictIPAddresses do
  def middleware(opts = {})
    @rip = described_class.new(lambda{|env| env}, opts)
  end

  def allowed(*addresses)
    url = URI.parse("http://test.com")
    ips  = addresses.map { |add| IPAddr.new(add).hton }

    # Socket returns a bunch of other stuff with gethostbyname. ipv6 addresses,
    # other socket information, whatever. We ignore it all internally and return
    # only valid ipv4 addresses, so just append what we're checking to some
    # garbage data like we expect.
    return_addresses = ['garbage', [], 30]
    return_addresses += ips
    Socket.expects(:gethostbyname).with(url.host).returns(return_addresses)

    env = { url: url }
    @rip.call(env)
  end

  def denied(*addresses)
    expect(-> { allowed(*addresses) }).to raise_error(Faraday::RestrictIPAddresses::AddressNotAllowed)
  end

    it "defaults to allowing everything" do
      middleware

      allowed '10.0.0.10'
      allowed '255.255.255.255'
    end

    it "allows disallowing addresses" do
      middleware deny: ["8.0.0.0/8"]

      allowed '7.255.255.255'
      denied  '8.0.0.1'
    end

    it "disallows addresses when any IP address is disallowed" do
      middleware deny: ["8.0.0.0/8"]

      denied '10.0.0.10', '8.8.8.8'
      allowed '10.0.0.10'
      denied '10.0.0.10', '8.8.8.8'
    end

    it "blacklists RFC1918 addresses" do
      middleware deny_rfc1918: true

      allowed '5.5.5.5'
      denied  '127.0.0.1'
      denied  '192.168.15.55'
      denied  '10.0.0.252'
    end

    it "blacklists RFC6890 addresses" do
      middleware deny_rfc6890: true

      allowed '5.5.5.5'
      denied  '240.15.15.15'
      denied  '192.168.15.55'
      denied  '10.0.0.252'
    end

    it "allows exceptions to disallowed addresses" do
      middleware deny_rfc1918: true,
                 allow: ["192.168.0.0/24"]

      allowed '192.168.0.15'
      denied  '192.168.1.0'
    end

    it "has an allow_localhost exception" do
      middleware deny_rfc1918: true,
                 allow_localhost: true
      denied  '192.168.0.15'
      allowed '127.0.0.1'
      denied  '127.0.0.5'
    end

    it "lets you mix and match your denied networks" do
      middleware deny_rfc1918: true,
                 deny: ['8.0.0.0/8'],
                 allow: ['8.5.0.0/24', '192.168.14.0/24']
      allowed '8.5.0.15'
      allowed '192.168.14.14'
      denied  '8.8.8.8'
      denied  '192.168.13.14'
    end

end
