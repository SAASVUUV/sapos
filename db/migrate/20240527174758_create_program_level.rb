class CreateProgramLevel < ActiveRecord::Migration[7.0]
  def up
    create_table :program_levels do |t|
      t.integer :level, null: false
      t.date :start_date, null: false
      t.date :end_date
      t.boolean :active, null: false

      t.timestamps
    end
    CustomVariable.where(variable: "program_level").each do |pl|
      level = pl.value
      program_level = ProgramLevel.create(
        level: pl.value,
        start_date: pl.updated_at,
        active: true
      )
      pl = pl.paper_trail.previous_version
      while pl.present?
        binding.pry
        if pl.value != level
          end_date = start_date
          start_date = pl.updated_at
          level = pl.value
          program_level = ProgramLevel.create(
            level: level,
            end_date: end_date,
            start_date: start_date,
            active: false
          )
        else
          start_date = pl.updated_at
          program_level.update(start_date: start_date)
        end
        pl.paper_trail.previous_version
      end
    end
    CustomVariable.where(variable: "program_level").destroy_all
  end
  def down
    ProgramLevel.all.each do |pl|
      CustomVariable.create(
        variable: "program_level",
        value: pl.level,
      )
    end
    drop_table :program_levels
  end
end
