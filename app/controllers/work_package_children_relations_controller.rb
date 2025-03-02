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

class WorkPackageChildrenRelationsController < ApplicationController
  include OpTurbo::ComponentStream
  include OpTurbo::DialogStreamHelper

  before_action :set_work_package

  before_action :authorize # Short-circuit early if not authorized

  def new
    component = WorkPackageRelationsTab::AddWorkPackageChildDialogComponent
      .new(work_package: @work_package)
    respond_with_dialog(component)
  end

  def create
    service_result = create_service_result

    if service_result.failure?
      update_via_turbo_stream(
        component: WorkPackageRelationsTab::AddWorkPackageChildFormComponent.new(work_package: @work_package,
                                                                                 child: service_result.result,
                                                                                 base_errors: base_errors(service_result.errors)),
        status: :bad_request
      )
    end

    respond_with_relations_tab_update(service_result, relation_to_scroll_to: service_result.result)
  end

  def destroy
    child = WorkPackage.find(params[:id])
    service_result = set_relation(child:, parent: nil)

    respond_with_relations_tab_update(service_result)
  end

  private

  def create_service_result
    if params[:work_package][:id].present?
      child = WorkPackage.find(params[:work_package][:id])
      set_relation(child:, parent: @work_package)
    else
      child = WorkPackage.new
      child.errors.add(:id, :blank)
      ServiceResult.failure(result: child)
    end
  end

  def set_relation(child:, parent:)
    if allowed_to_set_parent?(child)
      WorkPackages::UpdateService.new(user: current_user, model: child)
                                 .call(parent:)
    else
      child.errors.add(:id, :cannot_add_child_because_of_lack_of_permission)
      ServiceResult.failure(result: child)
    end
  end

  def allowed_to_set_parent?(child)
    contract = WorkPackages::UpdateContract.new(child, current_user)
    contract.can_set_parent?
  end

  def respond_with_relations_tab_update(service_result, **)
    if service_result.success?
      @work_package.reload
      component = WorkPackageRelationsTab::IndexComponent.new(work_package: @work_package, **)
      replace_via_turbo_stream(component:)
      render_success_flash_message_via_turbo_stream(message: I18n.t(:notice_successful_update))

      respond_with_turbo_streams
    else
      respond_with_turbo_streams(status: :unprocessable_entity)
    end
  end

  def set_work_package
    @work_package = WorkPackage.find(params[:work_package_id])
    @project = @work_package.project
  end

  def base_errors(errors)
    if errors[:base].present?
      errors[:base]
    elsif errors[:id].present?
      nil
    else
      errors.full_messages
    end
  end
end
