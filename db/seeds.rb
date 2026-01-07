# Job Extension Backend Seeds
puts "🌱 Seeding Job Extension Backend..."

# Create basic test users for Job Extension
users = [
  {
    email: "test@jobextension.com",
    first_name: "Test",
    last_name: "User", 
    plan: "pro",
    coin_balance: 100,
    password: "password123"
  },
  {
    email: "demo@jobextension.com",
    first_name: "Demo", 
    last_name: "User",
    plan: "free",
    coin_balance: 50,
    password: "password123"
  }
]

users.each do |user_data|
  user = User.find_or_create_by(email: user_data[:email]) do |u|
    u.first_name = user_data[:first_name]
    u.last_name = user_data[:last_name]
    u.plan = user_data[:plan]
    u.coin_balance = user_data[:coin_balance]
    u.password = user_data[:password]
    u.profile_data = {
      skills: ["Ruby on Rails", "JavaScript", "React"],
      experience: "3 years",
      location: "Remote"
    }
  end
  puts "✅ Created user: #{user.email} (Plan: #{user.plan}, Coins: #{user.coin_balance})"
end

# Create sample resume customizations
User.find_each do |user|
  next if user.customizations.any?
  
  user.customizations.create!(
    job_title: "Senior Software Engineer",
    company: "Tech Corp",
    posting_url: "https://jobs.techcorp.com/123",
    platform: "LinkedIn",
    ats_score: 85,
    keywords_matched: "Ruby on Rails, PostgreSQL, API development",
    keywords_missing: "Docker, Kubernetes",
    resume_content: "Customized resume content for Tech Corp application...",
    profile_snapshot: {
      skills_at_time: ["Ruby on Rails", "JavaScript", "React"],
      experience_at_time: "3 years"
    }
  )
  
  user.resume_versions.create!(
    job_title: "Senior Software Engineer",
    company: "Tech Corp", 
    posting_url: "https://jobs.techcorp.com/123",
    ats_score: 85,
    keywords_matched: ["Ruby on Rails", "PostgreSQL", "API development"],
    keywords_missing: ["Docker", "Kubernetes"],
    resume_content: "Resume tailored for Tech Corp Senior Engineer position...",
    profile_snapshot: {
      skills_at_time: ["Ruby on Rails", "JavaScript", "React"],
      experience_at_time: "3 years"
    }
  )
  
  puts "  📄 Created customization and resume version for #{user.email}"
end

puts "\n🎉 Job Extension Backend seeded successfully!"
puts "Summary:"
puts "- #{User.count} users"
puts "- #{Customization.count} customizations" 
puts "- #{ResumeVersion.count} resume versions"