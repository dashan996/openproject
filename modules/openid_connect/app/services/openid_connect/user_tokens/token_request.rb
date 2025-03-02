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
    class TokenRequest
      include Dry::Monads[:result]

      attr_reader :provider

      def initialize(provider:)
        @provider = provider
      end

      def refresh(refresh_token)
        request_token(form: { grant_type: :refresh_token, refresh_token: })
      end

      def exchange(access_token, audience)
        request_token(form: {
                        grant_type: "urn:ietf:params:oauth:grant-type:token-exchange",
                        subject_token: access_token,
                        audience:
                      })
      end

      private

      def request_token(form:)
        response = authenticated_request.post(provider.token_endpoint, form:)
        response.raise_for_status

        Success(response.json)
      rescue HTTPX::Error => e
        Failure(e)
      end

      def authenticated_request
        # According to https://www.rfc-editor.org/rfc/rfc6749.html#section-2.3.1
        # Client ID and Client Secret must be form-encoded. Otherwise characters such as colon (:)
        # would not be allowed in the Client ID, since HTTP Basic Auth does not support it
        # as per https://datatracker.ietf.org/doc/html/rfc7617#section-2
        OpenProject.httpx.basic_auth(CGI.escape(provider.client_id), CGI.escape(provider.client_secret))
      end
    end
  end
end
