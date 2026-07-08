class CreateAiReportHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_report_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :report_type, null: false
      t.json :filters
      t.json :ai_insights
      t.integer :confidence_score
      t.datetime :generated_at

      t.timestamps
    end

    add_index :ai_report_histories, [:user_id, :report_type]
    add_index :ai_report_histories, :generated_at
    add_index :ai_report_histories, :confidence_score
    add_index :ai_report_histories, :report_type
  end
end
