# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2024 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module OpenIDConnect
  module UserTokens
    class ExchangeService
      include Dry::Monads[:result]
      include Dry::Monads::Do.for(:call)

      class Disabled
        class << self
          include Dry::Monads[:result]

          def call(_) = Failure("Token exchange disabled")

          def supported? = false
        end
      end

      def initialize(user:)
        @user = user
      end

      def call(audience)
        return Failure("Provider does not support token exchange") unless supported?

        idp_token = yield FetchService.new(user: @user, token_exchange: Disabled)
                            .access_token_for(audience: UserToken::IDP_AUDIENCE)

        json = yield TokenRequest.new(provider:).exchange(idp_token, audience)

        access_token = json["access_token"]
        expires_in = json["expires_in"]
        return Failure("Token exchange response invalid") if access_token.blank?

        # We are explicitly opting to not store the refresh token for exchanged tokens
        # For one there is no need to store one, we can simply exchange a new token once the old expired.
        # A second reason is that at least Keycloak (an IDP we implement against), offers broken
        # refresh tokens after token exchange (see https://github.com/keycloak/keycloak/issues/37016)
        token = store_exchanged_token(audience:, access_token:, refresh_token: nil, expires_in:)
        Success(token)
      end

      def supported?
        provider&.token_exchange_capable?
      end

      private

      def store_exchanged_token(audience:, access_token:, refresh_token:, expires_in:)
        token_data = { access_token:, refresh_token:, expires_at: expires_in&.seconds&.from_now }
        token = @user.oidc_user_tokens.where("audiences ? :audience", audience:).first
        if token
          if token.audiences.size > 1
            raise "Did not expect to update token with multiple audiences (#{token.audiences}) in-place."
          end

          token.update!(**token_data)
        else
          token = @user.oidc_user_tokens.create!(audiences: [audience], **token_data)
        end

        token
      end

      def provider
        @user.authentication_provider
      end
    end
  end
end
