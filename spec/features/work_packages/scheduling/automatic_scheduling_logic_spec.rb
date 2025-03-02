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

require "spec_helper"
require "support/edit_fields/edit_field"

RSpec.describe "Automatic scheduling logic test cases (WP #61054)", :js, with_settings: { date_format: "%Y-%m-%d" } do
  shared_let(:user) { create(:admin) }

  shared_let(:type_bug) { create(:type_bug) }
  shared_let(:type_milestone) { create(:type_milestone) }
  shared_let(:project) { create(:project, types: [type_bug, type_milestone]) }

  shared_let(:bug_wp) { create(:work_package, project:, type: type_bug) }
  shared_let(:milestone_wp) { create(:work_package, project:, type: type_milestone) }

  # assume sat+sun are non working days
  shared_let(:week_days) { week_with_saturday_and_sunday_as_weekend }

  let(:work_packages_page) { Pages::FullWorkPackage.new(work_package, project) }
  let(:wp_table) { Pages::WorkPackagesTable.new(project) }

  let(:date_attribute) { :combinedDate }
  let(:date_field) { work_packages_page.edit_field(date_attribute) }
  let(:datepicker) { date_field.datepicker }

  let(:current_user) { user }
  let(:work_package) { bug_wp }

  def apply_and_expect_saved(attributes)
    date_field.save!

    work_packages_page.expect_and_dismiss_toaster message: I18n.t("js.notice_successful_update")

    work_package.reload

    attributes.each do |attr, value|
      expect(work_package.send(attr)).to eq value
    end
  end

  before do
    Setting.available_languages << current_user.language
    I18n.locale = current_user.language
    work_package.update_columns(current_attributes)
    login_as(current_user)

    work_packages_page.visit!
    work_packages_page.ensure_page_loaded
  end

  def open_date_picker
    date_field.activate!
    date_field.expect_active!
    # Wait for the datepicker to be initialized
    datepicker.expect_visible
  end

  describe "Scenario 25: Manual to automatic with no predecessors or children" do
    context "when there are no predecessors or children" do
      let(:current_attributes) do
        {
          start_date: Date.parse("2025-01-08"),
          due_date: Date.parse("2025-01-10"),
          duration: 3,
          schedule_manually: true
        }
      end

      it "cannot change scheduling mode to automatic" do
        open_date_picker
        datepicker.expect_manual_scheduling_mode

        datepicker.toggle_scheduling_mode
        datepicker.expect_automatic_scheduling_mode

        datepicker.expect_save_button_disabled
      end
    end
  end

  describe "Scenario 11 (GANTT/Team planner)" do
    context "when moving the left handle one day to the right" do
      it "reduces the duration by one day", skip: "to be implemented later"
    end
  end

  describe "Scenario 12 (GANTT/Team planner)" do
    context "when moving a work package to the right" do
      it "changes to later dates and keeps duration", skip: "to be implemented later"
    end
  end

  describe "Scenario 12bis (GANTT/Team planner)" do
    context "when moving a work package to the left" do
      it "changes to earlier dates and keeps duration", skip: "to be implemented later"
    end
  end

  describe "Scenario 26: Add a predecessor" do
    context "when adding a predecessor to a work package" do
      it "changes the work package dates to start right after its predecessor", skip: "to be implemented later"
    end
  end

  describe "Scenario 27a: Manual to automatic with multiple predecessors (no lag)" do
    context "when switching a work package with predecessors to automatic scheduling mode" do
      it "changes the work package dates to start right after its closest predecessor", skip: "to be implemented later"
    end
  end

  describe "Scenario 27b: Manual to automatic with multiple predecessors (with lag)" do
    context "when switching a work package with predecessors with lag to automatic scheduling mode" do
      it "changes the work package dates to start right after its closest predecessor", skip: "to be implemented later"
    end
  end

  describe "Scenario 28: Add children (parent in manual originally; children all manual, all in working days only)" do
    context "when adding first children to a work package" do
      it "switches its scheduling mode to automatic", skip: "to be implemented later"
    end
  end

  describe "Scenario 29: Add children (parent in manual originally; children all manual, mixed working days)" do
    context "when adding first children to a work package, one having working days only unchecked" do
      it "switches its scheduling mode to automatic with working days only unchecked", skip: "to be implemented later"
    end
  end

  describe "Scenario 30: Add children to a successor (start date derived children instead of predecessor)" do
    context "when adding manually scheduled children to an automatically scheduled work package being a successor" do
      it "updates its duration and dates based on the children dates, not based on its predecessors dates",
         skip: "to be implemented later"
    end
  end

  describe "Scenario 30a: Automatically-scheduled successor with children loses all its children (Child 1 removed first)" do
    context "when removing all children from an automatically scheduled work package being a successor" do
      it "ends up with duration and 'working days only' attributes based on last removed child (child 1) " \
         "and start date based on the predecessor", skip: "to be implemented later"
    end
  end

  describe "Scenario 30b: Automatically-scheduled successor with children loses all its children (Child 2 removed first)" do
    context "when removing all children from an automatically scheduled work package being a successor" do
      it "ends up with duration 'working days only' attributes based on last removed child (child 2) " \
         "and start date based on the predecessor", skip: "to be implemented later"
    end
  end

  describe "Scenario 32: Switch parent with predecessor and children to manual" do
    context "when switching a work package with predecessors and children to manual scheduling mode" do
      it "keeps its dates", skip: "to be implemented later"
    end
  end
end
