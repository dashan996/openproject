# frozen_string_literal: true

module OpPrimer
  # @logical_path OpenProject/Primer
  class StatusButtonComponentPreview < ViewComponent::Preview
    # See the [component documentation](/lookbook/pages/components/status_button) for more details.
    # @display min_height 200px
    # @param readonly [Boolean]
    # @param disabled [Boolean]
    # @param size [Symbol] select [small, medium, large]
    def playground(readonly: false, disabled: false, size: :medium)
      status = OpPrimer::StatusButtonOption.new(name: "Open",
                                                color: FactoryBot.build(:color_maroon),
                                                tag: :a,
                                                href: "/some/test")
      items = [
        status,
        OpPrimer::StatusButtonOption.new(name: "Closed",
                                         color: FactoryBot.build(:color_green),
                                         tag: :a,
                                         href: "/some/other/action")
      ]
      component = OpPrimer::StatusButtonComponent.new(current_status: status,
                                                      items:,
                                                      readonly:,
                                                      disabled:,
                                                      button_arguments: { title: "Edit", size: })

      render(component)
    end

    # See the [component documentation](/lookbook/pages/components/status_button) for more details.
    # @display min_height 200px
    def with_icon(size: :medium)
      status = OpPrimer::StatusButtonOption.new(name: "Open", icon: :unlock, color: Color.new(hexcode: "#FF0000"))

      items = [
        status,
        OpPrimer::StatusButtonOption.new(name: "Closed", icon: :lock, color: Color.new(hexcode: "#00FF00"))
      ]

      component = OpPrimer::StatusButtonComponent.new(current_status: status,
                                                      items: items,
                                                      readonly: false,
                                                      button_arguments: { size:, title: "foo" })

      render(component)
    end
  end
end
