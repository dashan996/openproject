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

RSpec.describe CustomField::OrderStatements do
  # integration tests at spec/models/query/results_cf_sorting_integration_spec.rb
  context "when hierarchy" do
    let(:service) { CustomFields::Hierarchy::HierarchicalItemService.new }
    let(:item) { service.generate_root(custom_field).value! }

    subject(:custom_field) { create(:hierarchy_wp_custom_field) }

    before do
      service.insert_item(parent: item, label: "Test")
    end

    describe "#order_statement" do
      it { expect(subject.order_statement).to eq("cf_order_#{custom_field.id}.value") }
    end

    describe "#order_join_statement" do
      # rubocop:disable RSpec/ExampleLength
      it "must be equal" do
        expect(custom_field.order_join_statement).to eq(
          <<-SQL.squish
            LEFT OUTER JOIN (
              SELECT DISTINCT ON (cv.customized_id) cv.customized_id , item.position "value" , cv.value ids
              FROM "custom_values" cv
              INNER JOIN (SELECT hi.id,
                      hi.parent_id,
                      SUM((1 + anc.sort_order) * power(2, 2 - depths.generations)) AS position,
                      hi.label,
                      hi.short,
                      hi.is_deleted,
                      hi.created_at,
                      hi.updated_at,
                      hi.custom_field_id
                FROM hierarchical_items hi
                      INNER JOIN hierarchical_item_hierarchies hih
                           ON hi.id = hih.descendant_id
                      JOIN hierarchical_item_hierarchies anc_h
                           ON anc_h.descendant_id = hih.descendant_id
                      JOIN hierarchical_items anc
                           ON anc.id = anc_h.ancestor_id
                      JOIN hierarchical_item_hierarchies depths
                           ON depths.ancestor_id = #{item.id} AND depths.descendant_id = anc.id
                WHERE hih.ancestor_id = #{item.id}
                GROUP BY hi.id) item ON item.id = cv.value::bigint
              WHERE cv.customized_type = 'WorkPackage'
              AND cv.custom_field_id = #{custom_field.id}
              AND cv.value IS NOT NULL
              AND cv.value != ''
              ORDER BY cv.customized_id, cv.id
            ) cf_order_#{custom_field.id} ON cf_order_#{custom_field.id}.customized_id = "work_packages".id
          SQL
        )
      end
      # rubocop:enable RSpec/ExampleLength
    end
  end
end
