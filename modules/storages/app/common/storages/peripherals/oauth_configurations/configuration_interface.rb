# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
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

module Storages
  module Peripherals
    module OAuthConfigurations
      class ConfigurationInterface
        using ServiceResultRefinements

        def scope = raise ::Storages::Errors::SubclassResponsibility

        def basic_rack_oauth_client = raise ::Storages::Errors::SubclassResponsibility

        def to_httpx_oauth_config = raise ::Storages::Errors::SubclassResponsibility

        def authorization_uri(state: nil)
          basic_rack_oauth_client.authorization_uri(scope:, state:)
        end

        def extract_origin_user_id(oauth_client_token)
          auth_strategy = Registry
                            .resolve("#{@storage}.authentication.user_bound")
                            .call(user: oauth_client_token.user, storage: @storage)
          Registry
            .resolve("#{@storage}.queries.user")
            .call(auth_strategy:, storage: @storage)
            .match(
              on_success: ->(user) { user[:id] },
              on_failure: ->(error) { raise "UserQuery responed with #{error}" }
            )
        end
      end
    end
  end
end
