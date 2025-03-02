# frozen_string_literal: true

FactoryBot.define do
  factory :oidc_user_token, class: "OpenIDConnect::UserToken" do
    transient do
      extra_audiences { nil }
    end

    user
    access_token { "INVALID_TOKEN" }
    refresh_token { "COOL_AID_TOKEN" }
    audiences { [OpenIDConnect::UserToken::IDP_AUDIENCE] + Array(extra_audiences) }
  end
end
