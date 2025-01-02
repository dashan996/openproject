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

module CustomField::OrderStatements
  # Returns the expression to use in ORDER BY clause to sort objects by their
  # value of the custom field.
  def order_statement
    case field_format
    when "string", "date", "bool", "link", "int", "float", "list", "user", "version", "hierarchy"
      "cf_order_#{id}.value"
    end
  end

  # Returns the join statement that is required to sort objects by their value
  # of the custom field.
  def order_join_statement
    case field_format
    when "string", "date", "bool", "link"
      join_for_order_by_string_sql
    when "int"
      join_for_order_by_int_sql
    when "float"
      join_for_order_by_float_sql
    when "list"
      join_for_order_by_list_sql
    when "user"
      join_for_order_by_user_sql
    when "version"
      join_for_order_by_version_sql
    when "hierarchy"
      join_for_order_by_hierarchy_sql
    end
  end

  # Returns the ORDER BY option defining order of objects without value for the
  # custom field.
  def order_null_handling(asc)
    null_direction = asc ? "FIRST" : "LAST"
    Arel.sql("NULLS #{null_direction}")
  end

  # Returns the expression to use in GROUP BY (and ORDER BY) clause to group
  # objects by their value of the custom field.
  def group_by_statement
    return unless can_be_used_for_grouping?

    order_statement
  end

  # Returns the expression to use in SELECT clause if it differs from one used
  # to group by
  def group_by_select_statement
    return unless field_format == "list" || field_format == "hierarchy"

    # MIN needed to not add this column to group by, ANY_VALUE can be used when
    # minimum required PostgreSQL becomes 16
    "MIN(cf_order_#{id}.ids)"
  end

  # Returns the join statement that is required to group objects by their value
  # of the custom field.
  def group_by_join_statement
    return unless can_be_used_for_grouping?

    order_join_statement
  end

  private

  def can_be_used_for_grouping? = field_format.in?(%w[list date bool int float string link hierarchy])

  # Template for all the join statements.
  #
  # For single value custom fields the join ensures single value for every
  # customized object using DISTINCT ON and selecting first value by id of
  # custom value:
  #
  #   LEFT OUTER JOIN (
  #     SELECT DISTINCT ON (cv.customized_id), cv.customized_id, xxx "value"
  #       FROM custom_values cv
  #       WHERE …
  #       ORDER BY cv.customized_id, cv.id
  #   ) cf_order_NNN ON cf_order_NNN.customized_id = …
  #
  # For multi value custom fields the GROUP BY and value aggregate function
  # ensure single value for every customized object:
  #
  #   LEFT OUTER JOIN (
  #     SELECT cv.customized_id, ARRAY_AGG(xxx ORDERY BY yyy) "value"
  #       FROM custom_values cv
  #       WHERE …
  #       GROUP BY cv.customized_id, cv.id
  #   ) cf_order_NNN ON cf_order_NNN.customized_id = …
  #
  def join_for_order_sql(value:, add_select: nil, join: nil, multi_value: false)
    <<-SQL.squish
      LEFT OUTER JOIN (
        SELECT
          #{multi_value ? '' : 'DISTINCT ON (cv.customized_id)'}
            cv.customized_id
            , #{value} "value"
            #{", #{add_select}" if add_select}
          FROM #{CustomValue.quoted_table_name} cv
          #{join}
          WHERE cv.customized_type = #{CustomValue.connection.quote(self.class.customized_class.name)}
            AND cv.custom_field_id = #{id}
            AND cv.value IS NOT NULL
            AND cv.value != ''
          #{multi_value ? 'GROUP BY cv.customized_id' : 'ORDER BY cv.customized_id, cv.id'}
      ) cf_order_#{id}
        ON cf_order_#{id}.customized_id = #{self.class.customized_class.quoted_table_name}.id
    SQL
  end

  def join_for_order_by_string_sql = join_for_order_sql(value: "cv.value")

  def join_for_order_by_int_sql = join_for_order_sql(value: "cv.value::decimal(60)")

  def join_for_order_by_float_sql = join_for_order_sql(value: "cv.value::double precision")

  def join_for_order_by_list_sql
    join_for_order_sql(
      value: multi_value? ? "ARRAY_AGG(co.position ORDER BY co.position)" : "co.position",
      add_select: "#{multi_value? ? "ARRAY_TO_STRING(ARRAY_AGG(cv.value ORDER BY co.position), '.')" : 'cv.value'} ids",
      join: "INNER JOIN #{CustomOption.quoted_table_name} co ON co.id = cv.value::bigint",
      multi_value:
    )
  end

  def join_for_order_by_user_sql
    columns_array = "ARRAY[users.lastname, users.firstname, users.mail]"

    join_for_order_sql(
      value: multi_value? ? "ARRAY_AGG(#{columns_array} ORDER BY #{columns_array})" : columns_array,
      join: "INNER JOIN #{User.quoted_table_name} users ON users.id = cv.value::bigint",
      multi_value:
    )
  end

  def join_for_order_by_version_sql
    join_for_order_sql(
      value: multi_value? ? "array_agg(versions.name ORDER BY versions.name)" : "versions.name",
      join: "INNER JOIN #{Version.quoted_table_name} versions ON versions.id = cv.value::bigint",
      multi_value:
    )
  end

  def join_for_order_by_hierarchy_sql
    ancestor_item = CustomField.find(id).hierarchy_root
    self_and_descendants = ancestor_item.self_and_descendants
    total_descendants = self_and_descendants.count
    max_depth = self_and_descendants.max_by(&:depth).depth
    items = hierarchy_position_sql(ancestor_id: ancestor_item.id, total_descendants:, max_depth:)

    join_for_order_sql(
      value: multi_value? ? "ARRAY_AGG(item.position ORDER BY item.position)" : "item.position",
      add_select: "#{multi_value? ? "ARRAY_TO_STRING(ARRAY_AGG(cv.value ORDER BY item.position), '.')" : 'cv.value'} ids",
      join: "INNER JOIN (#{items}) item ON item.id = cv.value::bigint",
      multi_value:
    )
  end

  # Template method for providing correct ordering of hierarchy items as a flat list for grouping
  #
  # In order to have groups correctly build with the structures above, a flat list of items is required like for
  # CustomOptions. CustomOptions naturally have a position field that encodes the ordering:
  #
  # | id | name | position | custom_field_id
  # ----------------------------------------
  # | 12 | foo  | 1        | 9
  # | 14 | foo  | 2        | 9
  # | 16 | foo  | 3        | 9
  #
  # For Hierarchy::Items this is different. They are organised in generations as they resemble a tree structure.
  # The `sort_order` field is used to encode the position in each generation:
  #
  # | id | name | parent_id | sort_order | custom_field_id
  # ------------------------------------------------------
  # | 12 | foo  | 1         | 0          | 9
  # | 14 | bar  | 12        | 0          | 9
  # | 16 | baz  | 2         | 1          | 9
  #
  # The `sort_order` field is not neatly consecutive numbers as for the CustomOption. That make it impossible to collect
  # the correct work packages for each group (see code).
  #
  # To overcome this problem the algorithms of closure_tree can be used. This method implements the same concept of
  # `self_and_descendants_preordered` from closure_tree. It uses the mathematical power operation to compute distinct
  # position values from `sort_order`, the total number of descendants and the maximum depth of the tree
  # (see implementation).
  def hierarchy_position_sql(ancestor_id:, total_descendants:, max_depth:)
    <<-SQL.squish
      SELECT hi.id,
            hi.parent_id,
            SUM((1 + anc.sort_order) * power(#{total_descendants}, #{max_depth + 1} - depths.generations)) AS position,
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
                 ON depths.ancestor_id = #{ancestor_id} AND depths.descendant_id = anc.id
     WHERE hih.ancestor_id = #{ancestor_id}
     GROUP BY hi.id
    SQL
  end
end
