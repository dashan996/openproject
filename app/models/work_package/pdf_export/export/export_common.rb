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

module WorkPackage::PDFExport::Export::ExportCommon
  def write_optional_page_break
    space_from_bottom = pdf.y - pdf.bounds.bottom
    if space_from_bottom < styles.page_break_threshold
      pdf.start_new_page
    end
  end

  def make_link_href_cell(href, caption)
    "<color rgb='#{styles.link_color}'><link href='#{href}'>#{caption}</link></color>"
  end

  def get_column_value_cell(work_package, column_name)
    value = get_column_value(work_package, column_name)
    return get_id_column_cell(work_package, value) if column_name == :id
    return get_subject_column_cell(work_package, value) if wants_report? && column_name == :subject

    escape_tags(value)
  end

  def get_id_column_cell(work_package, value)
    href = url_helpers.work_package_url(work_package)
    make_link_href_cell(href, value)
  end

  def get_subject_column_cell(work_package, value)
    make_link_anchor(work_package.id, escape_tags(value))
  end

  def get_column_value(work_package, column_name)
    formatter = formatter_for(column_name, :pdf)
    formatter.format(work_package)
  end

  def get_formatted_value(value, column_name)
    return "" if value.nil?

    formatter = formatter_for(column_name, :pdf)
    formatter.format_value(value, {})
  end

  def with_sums_table?
    query.display_sums?
  end

  def wants_report?
    options[:pdf_export_type] == "report"
  end

  def wants_gantt?
    options[:pdf_export_type] == "gantt"
  end

  def get_total_sums
    query.display_sums? ? (query.results.all_total_sums || {}) : {}
  end

  def get_group_sums(group)
    @group_sums ||= query.results.all_group_sums
    @group_sums[group] || {}
  end

  def get_groups
    query.results.work_package_count_by_group
         .select { |_, count| count > 0 }
         .map { |group, _| group }
  end
end
