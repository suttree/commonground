class PublishProfilesByDefault < ActiveRecord::Migration[8.1]
  def up
    change_column_default :submissions, :published, from: false, to: true
    execute "UPDATE submissions SET published = TRUE WHERE published = FALSE"
  end

  def down
    change_column_default :submissions, :published, from: true, to: false
  end
end
