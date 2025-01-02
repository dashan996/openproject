require "spec_helper"
require "features/page_objects/notification"

RSpec.describe "Notification center reminder, mention and date alert",
               :js,
               :with_cuprite,
               with_ee: %i[date_alerts],
               with_settings: { journal_aggregation_time_minutes: 0 } do
  shared_let(:project) { create(:project) }
  shared_let(:actor) { create(:user, firstname: "Actor", lastname: "User") }
  shared_let(:user) do
    create(:user,
           member_with_permissions: { project => %w[view_work_packages] })
  end
  shared_let(:work_package) { create(:work_package, project:, due_date: 1.day.ago) }

  shared_let(:notification_mention) do
    create(:notification,
           reason: :mentioned,
           recipient: user,
           resource: work_package,
           actor:)
  end

  shared_let(:notification_date_alert) do
    create(:notification,
           reason: :date_alert_due_date,
           recipient: user,
           resource: work_package)
  end

  shared_let(:notification_reminder) do
    reminder = create(:reminder, remindable: work_package, creator: user, note: "This is an important reminder")
    notification = create(:notification,
                          reason: :reminder,
                          recipient: user,
                          resource: work_package)
    create(:reminder_notification, reminder:, notification:)
    notification
  end

  let(:center) { Pages::Notifications::Center.new }

  before do
    login_as user
    visit notifications_center_path
    wait_for_reload
  end

  it "shows the reminder alert in own entry" do
    center.within_item(notification_reminder) do
      expect(page).to have_text("##{work_package.id}\n- #{project.name} -\nReminder")
      expect(page).to have_no_text("Actor user")
      expect(page).to have_text("a few seconds ago.\nNote: “This is an important reminder”")
    end
  end

  it "shows other notification reasons aggregated" do
    center.within_item(notification_date_alert) do
      expect(page).to have_text("##{work_package.id}\n- #{project.name} -\nDate alert, Mentioned")
      expect(page).to have_no_text("Actor user")
    end
  end
end
