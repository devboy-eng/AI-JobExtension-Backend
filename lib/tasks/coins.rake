namespace :coins do
  desc "Add coins to a user account"
  task :add, [:email, :amount] => :environment do |t, args|
    email = args[:email]
    amount = args[:amount].to_i
    
    user = User.find_by(email: email)
    if user
      user.add_coins(amount, "Admin added coins for testing")
      puts "✅ Added #{amount} coins to #{email}. New balance: #{user.coin_balance}"
    else
      puts "❌ User with email #{email} not found"
    end
  end
  
  desc "Check coin balance for a user"
  task :balance, [:email] => :environment do |t, args|
    email = args[:email]
    user = User.find_by(email: email)
    if user
      puts "💰 User #{email} has #{user.coin_balance} coins"
    else
      puts "❌ User with email #{email} not found"
    end
  end
  
  desc "Set exact coin balance for a user"
  task :set, [:email, :amount] => :environment do |t, args|
    email = args[:email]
    amount = args[:amount].to_i
    
    user = User.find_by(email: email)
    if user
      user.update!(coin_balance: amount)
      puts "✅ Set coin balance for #{email} to #{amount} coins"
    else
      puts "❌ User with email #{email} not found"
    end
  end
end