# frozen_string_literal: true

class WorkPackageRelationsTab::IndexComponent < ApplicationComponent
  FRAME_ID = "work-package-relations-tab-content"
  NEW_RELATION_ACTION_MENU = "new-relation-action-menu"
  I18N_NAMESPACE = "work_package_relations_tab"
  include ApplicationHelper
  include OpPrimer::ComponentHelpers
  include Turbo::FramesHelper
  include OpTurbo::Streamable

  attr_reader :work_package, :relations, :children, :directionally_aware_grouped_relations, :scroll_to_id

  def initialize(work_package:, relations:, children:, scroll_to_id: nil)
    super()

    @work_package = work_package
    @relations = relations
    @children = children
    @directionally_aware_grouped_relations = group_relations_by_directional_context
    @scroll_to_id = scroll_to_id
  end

  def self.wrapper_key
    FRAME_ID
  end

  private

  def should_render_add_child?
    helpers.current_user.allowed_in_project?(:manage_subtasks, @work_package.project)
  end

  def should_render_add_relations?
    helpers.current_user.allowed_in_project?(:manage_work_package_relations, @work_package.project)
  end

  def should_render_create_button?
    should_render_add_child? || should_render_add_relations?
  end

  def group_relations_by_directional_context
    relations.group_by do |relation|
      relation.relation_type_for(work_package)
    end
  end

  def any_relations? = relations.any? || children.any?

  def render_relation_group(title:, relation_type:, items:, &_block)
    render(border_box_container(
             padding: :condensed,
             data: { test_selector: "op-relation-group-#{relation_type}" }
           )) do |border_box|
      render_header(border_box, title, items)
      render_items(border_box, items, &_block)
    end
  end

  def render_header(border_box, title, items)
    border_box.with_header(py: 3) do
      flex_layout(align_items: :center) do |flex|
        flex.with_column(mr: 2) do
          render(Primer::Beta::Text.new(font_size: :normal, font_weight: :bold)) { title }
        end
        flex.with_column do
          render(Primer::Beta::Counter.new(count: items.size, round: true, scheme: :primary))
        end
      end
    end
  end

  def render_items(border_box, items)
    items.each do |item|
      related_work_package_id = find_related_work_package_id(item)
      data_attribute = nil
      if related_work_package_id.to_s == @scroll_to_id
        data_attribute = {
          controller: "work-packages--relations-tab--scroll",
          application_target: "dynamic",
          "work-packages--relations-tab--scroll-target": "scrollToRow"
        }
      end
      border_box.with_row(
        test_selector: row_test_selector(item),
        data: data_attribute
      ) do
        yield(item)
      end
    end
  end

  def new_relation_path(relation_type:)
    raise ArgumentError, "Invalid relation type: #{relation_type}" unless Relation::TYPES.key?(relation_type)

    if relation_type == Relation::TYPE_CHILD
      raise NotImplementedError, "Child relations are not supported yet"
    else
      new_work_package_relation_path(work_package, relation_type:)
    end
  end

  def new_button_test_selector(relation_type:)
    "op-new-relation-button-#{relation_type}"
  end

  def row_test_selector(item)
    related_work_package_id = find_related_work_package_id(item)
    "op-relation-row-#{related_work_package_id}"
  end

  def find_related_work_package_id(item)
    if item.is_a?(Relation)
      item.from_id == work_package.id ? item.to_id : item.from_id
    else
      item.id
    end
  end
end
