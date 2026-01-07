namespace :demo do
  desc "Setup demo data for Job Extension admin panel"
  task setup: :environment do
    puts "🚀 Setting up Job Extension demo data..."
    
    # Create demo users
    users_data = [
      {
        email: 'john.doe@example.com',
        password: 'password123',
        plan: 'free',
        coin_balance: 25
      },
      {
        email: 'jane.smith@example.com', 
        password: 'password123',
        plan: 'pro',
        coin_balance: 100
      },
      {
        email: 'mike.wilson@example.com',
        password: 'password123', 
        plan: 'free',
        coin_balance: 5
      },
      {
        email: 'sarah.johnson@example.com',
        password: 'password123',
        plan: 'monthly_pro', 
        coin_balance: 75
      },
      {
        email: 'test.user@example.com',
        password: 'password123',
        plan: 'free',
        coin_balance: 50
      }
    ]
    
    users_data.each do |user_data|
      user = User.find_or_create_by(email: user_data[:email]) do |u|
        u.password = user_data[:password]
        u.plan = user_data[:plan]
        u.coin_balance = user_data[:coin_balance]
        # Initialize profile_data
        u.profile_data = {
          name: user_data[:email].split('@').first.titleize,
          designation: 'Software Engineer',
          summary: 'Experienced professional seeking new opportunities'
        }
      end
      
      # Create some AI customizations for demo
      if user.persisted? && user.customizations.count == 0
        2.times do |i|
          user.customizations.create!(
            job_title: ['Software Engineer', 'Full Stack Developer', 'Backend Engineer', 'Frontend Developer'].sample,
            company: ['Tech Corp', 'StartupXYZ', 'MegaTech Inc', 'Innovation Labs'].sample,
            posting_url: 'https://example.com/jobs/123',
            platform: 'linkedin',
            ats_score: rand(60..95),
            keywords_matched: ['JavaScript', 'React', 'Node.js'].sample(2),
            keywords_missing: ['Python', 'Docker', 'AWS'].sample(1),
            resume_content: '<div>Sample resume content</div>',
            profile_snapshot: user.profile_data
          )
        end
      end
      
      puts "✅ Created user: #{user.email} (#{user.plan}) with #{user.coin_balance} coins"
    end
    
    puts "\n🎉 Demo setup complete!"
    puts "\n📊 Summary:"
    puts "   Total users: #{User.count}"
    puts "   Total coins distributed: #{User.sum(:coin_balance)}"
    puts "   Total customizations: #{Customization.count}"
    puts "\n🔗 Admin Panel: http://localhost:4003/simple-admin"
    puts "   Login: admin / admin123"
  end
  
  desc "Clear demo data"
  task clear: :environment do
    puts "🧹 Clearing demo data..."
    User.destroy_all
    Customization.destroy_all
    puts "✅ Demo data cleared!"
  end
end