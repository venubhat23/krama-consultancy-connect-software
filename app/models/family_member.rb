class FamilyMember < ApplicationRecord
  belongs_to :customer
  has_many :documents, as: :documentable, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
  RELATIONSHIPS = [
    'father', 'mother', 'spouse', 'husband', 'wife',
    'son', 'daughter', 'child',
    'brother', 'sister', 'sibling',
    'grandfather', 'grandmother', 'grandson', 'granddaughter',
    'uncle', 'aunt', 'nephew', 'niece', 'cousin',
    'father-in-law', 'mother-in-law', 'son-in-law', 'daughter-in-law',
    'brother-in-law', 'sister-in-law',
    'stepfather', 'stepmother', 'stepson', 'stepdaughter',
    'guardian', 'ward', 'other'
  ].freeze

  validates :relationship, presence: true, inclusion: { in: RELATIONSHIPS }

  enum :relationship, {
    father: 'father',
    mother: 'mother',
    spouse: 'spouse',
    husband: 'husband',
    wife: 'wife',
    son: 'son',
    daughter: 'daughter',
    child: 'child',
    brother: 'brother',
    sister: 'sister',
    sibling: 'sibling',
    grandfather: 'grandfather',
    grandmother: 'grandmother',
    grandson: 'grandson',
    granddaughter: 'granddaughter',
    uncle: 'uncle',
    aunt: 'aunt',
    nephew: 'nephew',
    niece: 'niece',
    cousin: 'cousin',
    father_in_law: 'father-in-law',
    mother_in_law: 'mother-in-law',
    son_in_law: 'son-in-law',
    daughter_in_law: 'daughter-in-law',
    brother_in_law: 'brother-in-law',
    sister_in_law: 'sister-in-law',
    stepfather: 'stepfather',
    stepmother: 'stepmother',
    stepson: 'stepson',
    stepdaughter: 'stepdaughter',
    guardian: 'guardian',
    ward: 'ward',
    other_relationship: 'other'
  }
  enum :gender, { male: 'male', female: 'female', other_gender: 'other' }

  accepts_nested_attributes_for :documents, allow_destroy: true, reject_if: :all_blank

  before_save :calculate_age

  def full_name
    "#{first_name} #{middle_name} #{last_name}".strip.squeeze(' ')
  end

  def name
    full_name
  end

  private

  def calculate_age
    if birth_date.present?
      self.age = Date.current.year - birth_date.year
      self.age -= 1 if Date.current < birth_date + age.years
    end
  end
end
