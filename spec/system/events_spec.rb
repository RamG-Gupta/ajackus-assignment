require "rails_helper"

RSpec.describe "Event listing", type: :system do
  before { driven_by :selenium, using: :headless_chrome }

  it "shows event details, vote counts, and disabled vote controls before sign-in" do
    event = Event.create!(
      external_id: "browser-event-1",
      title: "Browser test event",
      starts_at: Time.zone.parse("2030-06-01 18:00:00")
    )
    EventVote.create!(event: event, clerk_user_id: "user_browser", value: "up")

    visit events_path

    expect(page).to have_content("Browser test event")
    expect(page).to have_content("Upvotes: 1")
    expect(page).to have_button("Like", disabled: true)
    expect(page).to have_button("Dislike", disabled: true)
    expect(page).to have_button("Remove vote", disabled: true)
  end
end
