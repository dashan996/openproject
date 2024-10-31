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

class WorkPackageRelationsTab::EditWorkPackageRelationFormComponent < ApplicationComponent
  include ApplicationHelper
  include OpTurbo::Streamable
  include OpPrimer::ComponentHelpers

  FORM_ID = "edit-work-package-relation-form"
  STIMULUS_CONTROLLER = "work-packages--relations-tab--relation-form"
  I18N_NAMESPACE = "work_package_relations_tab"

  def initialize(work_package:, relation:, base_errors: nil)
    super()

    @work_package = work_package
    @relation = relation
    @base_errors = base_errors
  end

  def not_parent_child_relation?
    @relation.is_a?(Relation)
  end

  def related_work_package
    @related_work_package ||= case @relation
                              when Relation
                                @relation.to
                              when WorkPackage
                                @relation
                              end
  end
end
