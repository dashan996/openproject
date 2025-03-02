# frozen_string_literal: true

require "spec_helper"

require "services/base_services/behaves_like_create_service"

RSpec.describe RemoteIdentities::CreateService, :storage_server_helpers, :webmock, type: :model do
  let(:user) { create(:user) }
  let(:storage) { create(:nextcloud_storage_configured) }
  let(:oauth_config) { storage.oauth_configuration }
  let(:oauth_client_token) do
    create(:oauth_client_token,
           user:,
           oauth_client: oauth_config.oauth_client)
  end

  subject(:service) { described_class.new(user:, oauth_config:, oauth_client_token:) }

  before { stub_nextcloud_user_query(storage.host) }

  describe ".call" do
    it "requires a user, a oauth configuration and a rack token" do
      method = described_class.method :call

      expect(method.parameters).to contain_exactly(%i[keyreq user], %i[keyreq oauth_config], %i[keyreq oauth_client_token])
    end

    it "succeeds", :webmock do
      expect(described_class.call(user:, oauth_config:, oauth_client_token:)).to be_success
    end
  end

  describe "#user" do
    it "exposes a user which is available as a getter" do
      expect(service.user).to eq(user)
    end
  end

  describe "#call" do
    it "succeeds" do
      expect(service.call).to be_success
    end

    it "returns the model as a result" do
      result = service.call.result
      expect(result).to be_a RemoteIdentity
    end
  end
end
