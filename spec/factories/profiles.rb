FactoryBot.define do
  factory :profile do
    user { nil }
    name { "MyString" }
    designation { "MyString" }
    email { "MyString" }
    phone { "MyString" }
    address { "MyString" }
    linkedin { "MyString" }
    skills { "MyText" }
    education { "MyText" }
    languages { "MyString" }
    work_experience { "MyText" }
    certificates { "MyText" }
  end
end
