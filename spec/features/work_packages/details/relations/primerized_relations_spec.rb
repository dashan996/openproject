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

RSpec.describe "Primerized work package relations tab",
               :js, :with_cuprite do
  let(:user) { create(:admin) }
  let(:project) { create(:project) }
  let(:work_package) { create(:work_package, project:) }
  let(:full_wp_view) { Pages::FullWorkPackage.new(work_package) }
  let(:relations_tab) { Components::WorkPackages::Relations.new(work_package) }
  let(:relations_panel_selector) { ".detail-panel--relations" }
  let(:relations_panel) { find(relations_panel_selector) }
  let(:work_packages_page) { Pages::PrimerizedSplitWorkPackage.new(work_package) }
  let(:tabs) { Components::WorkPackages::PrimerizedTabs.new }

  let(:type1) { create(:type) }
  let(:type2) { create(:type) }

  let(:to1) { create(:work_package, type: type1, project:) }
  let(:to2) { create(:work_package, type: type2, project:) }
  let(:from1) { create(:work_package, type: type1, project:) }

  let!(:relation1) do
    create(:relation,
           from: work_package,
           to: to1,
           relation_type: Relation::TYPE_FOLLOWS)
  end
  let!(:relation2) do
    create(:relation,
           from: work_package,
           to: to2,
           relation_type: Relation::TYPE_RELATES)
  end
  let!(:relation3) do
    create(:relation,
           from: from1,
           to: work_package,
           relation_type: Relation::TYPE_BLOCKED)
  end
  let!(:relation4) do
    create(:relation,
           from: to1,
           to: from1,
           relation_type: Relation::TYPE_FOLLOWS)
  end
  let!(:child_wp) do
    create(:work_package,
           parent: work_package,
           type: type1,
           project: project)
  end

  current_user { user }

  def label_for_relation_type(relation_type)
    I18n.t("work_package_relations_tab.relations.label_#{relation_type}_plural").capitalize
  end

  before do
    work_packages_page.visit_tab!("relations")
    expect_angular_frontend_initialized
    work_packages_page.expect_subject
    loading_indicator_saveguard
  end

  describe "rendering" do
    it "renders the relations tab" do
      scroll_to_element relations_panel
      expect(page).to have_css(relations_panel_selector)

      [relation1, relation2].each do |relation|
        target = relation.to == work_package ? "from" : "to"
        target_relation_type = target == "from" ? relation.reverse_type : relation.relation_type

        within(relations_panel) do
          expect(page).to have_text(relation.to.type.name.upcase)
          expect(page).to have_text(relation.to.id)
          expect(page).to have_text(relation.to.status.name)
          expect(page).to have_text(relation.to.subject)
          # We reference the reverse type as the "from" node of the relation
          # is the currently visited work package, and the "to" node is the
          # relation target. From the current user's perspective on the work package's
          # page, this is the "reverse" relation.
          expect(page).to have_text(label_for_relation_type(target_relation_type))
        end
      end

      target = relation3.to == work_package ? "from" : "to"
      target_relation_type = target == "from" ? relation3.reverse_type : relation3.relation_type

      within(relations_panel) do
        expect(page).to have_text(relation3.to.type.name.upcase)
        expect(page).to have_text(relation3.to.id)
        expect(page).to have_text(relation3.to.status.name)
        expect(page).to have_text(relation3.to.subject)
        # We reference the relation type as the "from" node of the relation
        # is not the currently visited work package. From the current user's
        # perspective on the work package's page, this is the "forward" relation.
        expect(page).to have_text(label_for_relation_type(target_relation_type))
      end
    end
  end

  describe "deletion" do
    it "can delete relations" do
      scroll_to_element relations_panel

      # Find the first relation and delete it
      relation_row = relations_panel.find("[data-test-selector='op-relation-row-#{relation1.id}']")

      within(relation_row) do
        page.find("[data-test-selector='op-relation-row-#{relation1.id}-action-menu']").click
        page.find("[data-test-selector='op-relation-row-#{relation1.id}-delete-button']").click
      end

      wait_for_reload

      # Expect the relation to be gone
      within "##{WorkPackageRelationsTab::IndexComponent::FRAME_ID}" do
        expect(page).to have_no_text(relation1.to.subject)
      end

      expect { relation1.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "can delete children" do
      scroll_to_element relations_panel

      # Find the first relation and delete it
      child_row = relations_panel.find("[data-test-selector='op-relation-row-#{child_wp.id}']")

      within(child_row) do
        page.find("[data-test-selector='op-relation-row-#{child_wp.id}-action-menu']").click
        page.find("[data-test-selector='op-relation-row-#{child_wp.id}-delete-button']").click
      end

      wait_for_reload

      within "##{WorkPackageRelationsTab::IndexComponent::FRAME_ID}" do
        expect(page).to have_no_text(child_wp.subject)
      end

      expect(child_wp.reload.parent).to be_nil
    end
  end

  describe "editing" do
    it "renders an edit form" do
      scroll_to_element relations_panel

      relation_row = relations_panel.find("[data-test-selector='op-relation-row-#{relation1.id}']")

      within(relation_row) do
        page.find("[data-test-selector='op-relation-row-#{relation1.id}-action-menu']").click
        page.find("[data-test-selector='op-relation-row-#{relation1.id}-edit-button']").click
      end

      within "##{WorkPackageRelationsTab::EditWorkPackageRelationDialogComponent::DIALOG_ID}" do
        wait_for_network_idle
        expect(page).to have_text("Edit successor (after)")
        expect(page).to have_button("Add description")
        expect(page).to have_field("Description", visible: :hidden)

        click_link_or_button "Add description"

        expect(page).to have_field("Description")

        fill_in "Description", with: "Discovered relations have descriptions!"

        click_link_or_button "Save"
      end

      # Reflects new description
      wait_for_reload
      within(relation_row) do
        expect(page).to have_text("Discovered relations have descriptions!")
      end

      # Edit again
      within(relation_row) do
        page.find("[data-test-selector='op-relation-row-#{relation1.id}-action-menu']").click
        page.find("[data-test-selector='op-relation-row-#{relation1.id}-edit-button']").click
      end

      within "##{WorkPackageRelationsTab::EditWorkPackageRelationDialogComponent::DIALOG_ID}" do
        wait_for_network_idle
        expect(page).to have_text("Edit successor (after)")
        expect(page).to have_no_button("Add description")
        expect(page).to have_field("Description", visible: :visible, with: "Discovered relations have descriptions!")

        fill_in "Description", with: "And they can be edited!"

        click_link_or_button "Save"
      end

      # Reflects new description
      wait_for_reload
      within(relation_row) do
        expect(page).to have_text("And they can be edited!")
      end
    end
  end
end
