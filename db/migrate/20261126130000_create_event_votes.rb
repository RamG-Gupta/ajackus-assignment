class CreateEventVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :event_votes do |t|
      t.references :event, null: false, foreign_key: true
      t.string :clerk_user_id, null: false
      t.string :value, null: false
      t.timestamps
    end

    add_index :event_votes, %i[event_id clerk_user_id], unique: true
    add_check_constraint :event_votes, "value IN ('up', 'down')", name: "event_votes_value_check"
  end
end
