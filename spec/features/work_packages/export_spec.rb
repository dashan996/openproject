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
require "features/work_packages/work_packages_page"

RSpec.describe "work package export" do
  let(:project) { create(:project_with_types, types: [type_a, type_b]) }
  let(:export_type) { "CSV" }
  let(:current_user) { create(:admin) }
  let(:type_a) { create(:type, name: "Type A") }
  let(:type_b) { create(:type, name: "Type B") }
  let(:wp1) { create(:work_package, project:, done_ratio: 25, type: type_a) }
  let(:wp2) { create(:work_package, project:, done_ratio: 0, type: type_a) }
  let(:wp3) { create(:work_package, project:, done_ratio: 0, type: type_b) }
  let(:wp4) { create(:work_package, project:, done_ratio: 0, type: type_a) }
  let(:work_packages_page) { WorkPackagesPage.new(project) }
  let(:wp_table) { Pages::WorkPackagesTable.new(project) }
  let(:settings_menu) { Components::WorkPackages::SettingsMenu.new }
  let(:export_sub_type) { nil }
  let(:expected_params) { {} }
  let(:expected_mime_type) { anything }
  let(:query) { create(:query, user: current_user, project:) }
  let(:expected_columns) { query.displayable_columns.map { |c| c.name.to_s } - ["bcf_thumbnail"] }
  let(:default_params) { {} }

  before do
    service_instance = instance_double(WorkPackages::Exports::ScheduleService)
    allow(WorkPackages::Exports::ScheduleService)
      .to receive(:new)
            .with(user: current_user)
            .and_return(service_instance)

    allow(service_instance)
      .to receive(:call)
            .with(query: anything, mime_type: expected_mime_type, params: has_mandatory_params(expected_params))
            .and_return(ServiceResult.success(result: "uuid of the export job"))

    wp1
    wp2
    wp3
    wp4

    query.column_names = expected_columns
    query.save!

    login_as(current_user)
  end

  RSpec::Matchers.define :has_mandatory_params do |expected|
    match do |actual|
      expected.count do |key, value|
        actual[key.to_sym] == value
      end == expected.size
    end
  end

  def open_export_dialog!
    wp_table.visit_query query
    work_packages_page.ensure_loaded
    settings_menu.open_and_choose I18n.t("js.toolbar.settings.export")
    click_on export_type
  end

  def export!
    click_on I18n.t("export.dialog.submit")
  end

  context "with Query options", :js do
    let(:export_type) { I18n.t("export.dialog.format.options.pdf.label") }
    let(:expected_mime_type) { :pdf }

    before do
      open_export_dialog!
    end

    # these values must be looped through the dialog into the export

    context "with activated options" do
      let(:query) do
        create(
          :query, user: current_user, project:,
                  display_sums: true,
                  include_subprojects: true,
                  show_hierarchies: true
        )
      end
      let(:expected_params) do
        {
          showSums: "true",
          includeSubprojects: "true",
          showHierarchies: "true"
        }
      end

      it "starts an export with looped through values" do
        export!
      end
    end

    context "with grouping" do
      let(:query) { create(:query, user: current_user, project:, group_by: "project") }
      let(:expected_params) { { groupBy: "project" } }

      it "starts an export grouped" do
        export!
      end
    end
  end

  context "with CSV export", :js do
    let(:export_type) { I18n.t("export.dialog.format.options.csv.label") }
    let(:expected_mime_type) { :csv }
    let(:expected_params) { default_params }

    before do
      open_export_dialog!
    end

    it "exports a csv" do
      export!
    end
  end

  context "with XLS export", :js do
    let(:export_type) { I18n.t("export.dialog.format.options.xls.label") }
    let(:expected_mime_type) { :xls }

    before do
      open_export_dialog!
    end

    context "with relations" do
      let(:expected_params) { default_params.merge({ show_relations: "true" }) }

      it "exports a xls" do
        check I18n.t("export.dialog.xls.include_relations.label")
        export!
      end
    end

    context "without relations" do
      let(:expected_params) { default_params.merge({ show_relations: "false" }) }

      it "exports a xls" do
        uncheck I18n.t("export.dialog.xls.include_relations.label")
        export!
      end
    end

    context "with descriptions" do
      let(:expected_params) { default_params.merge({ show_descriptions: "true" }) }

      it "exports a xls" do
        check I18n.t("export.dialog.xls.include_descriptions.label")
        export!
      end
    end

    context "without descriptions" do
      let(:expected_params) { default_params.merge({ show_descriptions: "false" }) }

      it "exports a xls" do
        uncheck I18n.t("export.dialog.xls.include_descriptions.label")
        export!
      end
    end
  end

  context "with PDF export", :js do
    let(:expected_mime_type) { :pdf }

    before do
      open_export_dialog!
    end

    context "as table" do
      let(:export_type) { I18n.t("export.dialog.format.options.pdf.label") }
      let(:export_sub_type) { I18n.t("export.dialog.pdf.export_type.options.table.label") }
      let(:expected_params) { default_params.merge({ pdf_export_type: "table" }) }

      it "exports a pdf table" do
        choose export_sub_type
        export!
      end
    end

    context "as report" do
      let(:export_type) { I18n.t("export.dialog.format.options.pdf.label") }
      let(:export_sub_type) { I18n.t("export.dialog.pdf.export_type.options.report.label") }

      context "with image" do
        let(:expected_params) { default_params.merge({ pdf_export_type: "report", show_images: "true" }) }

        it "exports a pdf report with image by default" do
          choose export_sub_type
          export!
        end

        it "exports a pdf report with checked input" do
          choose export_sub_type
          check I18n.t("export.dialog.pdf.include_images.label")
          export!
        end
      end

      context "without images" do
        let(:expected_params) { default_params.merge({ pdf_export_type: "report", show_images: "false" }) }

        it "exports a pdf report with checked input" do
          choose export_sub_type
          uncheck I18n.t("export.dialog.pdf.include_images.label")
          export!
        end
      end
    end

    context "as gantt" do
      let(:export_type) { I18n.t("export.dialog.format.options.pdf.label") }
      let(:export_sub_type) { I18n.t("export.dialog.pdf.export_type.options.gantt.label") }

      context "with EE not active" do
        it "gantt is disabled" do
          expect(page).to have_field("pdf_export_type_gantt", type: "radio", disabled: true)
        end
      end

      context "with EE active", with_ee: %i[gantt_pdf_export] do
        let(:expected_params) { default_params.merge({ pdf_export_type: "gantt" }) }

        before do
          choose export_sub_type
        end

        it "exports a gantt chart pdf" do
          export!
        end

        context "with zoom level" do
          let(:expected_params) { default_params.merge({ pdf_export_type: "gantt", gantt_mode: "week" }) }

          it "exports a pdf gantt chart by weeks" do
            select I18n.t("export.dialog.pdf.gantt_zoom_levels.options.weeks"), from: "gantt_mode"
            export!
          end
        end

        context "with column width" do
          let(:expected_params) { default_params.merge({ pdf_export_type: "gantt", gantt_width: "very_wide" }) }

          it "exports a pdf gantt chart by column width" do
            select I18n.t("export.dialog.pdf.column_width.options.very_wide"), from: "gantt_width"
            export!
          end
        end

        context "with paper size" do
          let(:expected_params) { default_params.merge({ pdf_export_type: "gantt", paper_size: "A1" }) }

          it "exports a pdf gantt chart in A1" do
            select "A1", from: "paper_size"
            export!
          end
        end
      end
    end
  end
end
