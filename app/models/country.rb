# Copyright (c) Universidade Federal Fluminense (UFF).
# This file is part of SAPOS. Please, consult the license terms in the LICENSE file.

# frozen_string_literal: true

# Represents a Country
class Country < ApplicationRecord
  has_paper_trail

  has_many :state, dependent: :restrict_with_exception
  has_many :student_birth_countries, class_name: "Student", foreign_key: "birth_country_id", dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true

  def to_label
    "#{self.name}"
  end
end
