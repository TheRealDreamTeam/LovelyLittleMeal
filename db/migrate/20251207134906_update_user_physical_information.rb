class UpdateUserPhysicalInformation < ActiveRecord::Migration[7.1]
  def up
    # Remove old boolean gender column
    remove_column :users, :gender, :boolean

    # Add new enum columns
    add_column :users, :gender, :integer, default: 2 # prefer_not_to_say
    add_column :users, :height, :integer # Height in cm
    add_column :users, :activity_level, :integer, default: 1 # lightly_active
    add_column :users, :goal, :integer, default: 1 # maintain_weight

    # Add indexes for enum columns (optional, but can help with queries)
    add_index :users, :gender
    add_index :users, :activity_level
    add_index :users, :goal
  end

  def down
    # Remove new columns
    remove_index :users, :goal if index_exists?(:users, :goal)
    remove_index :users, :activity_level if index_exists?(:users, :activity_level)
    remove_index :users, :gender if index_exists?(:users, :gender)

    remove_column :users, :goal, :integer
    remove_column :users, :activity_level, :integer
    remove_column :users, :height, :integer
    remove_column :users, :gender, :integer

    # Restore old boolean gender column
    add_column :users, :gender, :boolean
  end
end
