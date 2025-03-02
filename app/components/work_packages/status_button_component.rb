# frozen_string_literal: true

class WorkPackages::StatusButtonComponent < OpPrimer::StatusButtonComponent
  include Primer::ClassNameHelper

  attr_reader :work_package, :user

  def initialize(work_package:, user:, readonly: false, button_arguments: {}, menu_arguments: {})
    @work_package = work_package
    @user = user

    button_arguments[:classes] = class_names(
      button_arguments[:classes],
      "__hl_background_status_#{work_package.status.id}"
    )

    super(
      current_status: map_status(work_package.status),
      items: available_statuses,
      readonly:,
      button_arguments:,
      menu_arguments:
    )
  end

  def default_button_title
    I18n.t("js.label_edit_status")
  end

  def disabled?
    !user.allowed_in_project?(:edit_work_packages, work_package.project)
  end

  def available_statuses
    WorkPackages::UpdateContract
      .new(work_package, user)
      .assignable_statuses
      .map { |status| map_status(status) }
  end

  def map_status(status)
    icon = status.is_readonly? ? :lock : nil
    OpPrimer::StatusButtonOption.new(name: status.name, color: status.color, icon:)
  end
end
