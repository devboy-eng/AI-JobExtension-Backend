FactoryBot.define do
  factory :resume_version do
    user { nil }
    job_title { "MyString" }
    company { "MyString" }
    posting_url { "MyText" }
    ats_score { 1 }
    keywords_matched { "" }
    keywords_missing { "" }
    resume_content { "MyText" }
    profile_snapshot { "" }
  end
end
