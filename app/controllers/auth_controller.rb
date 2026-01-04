class AuthController < ApplicationController
  # Simple in-memory storage for customization history
  @@customization_history = {}
  def create
    user = User.new(user_params)
    
    if user.save
      token = generate_token(user)
      render json: {
        success: true,
        user: user_response(user),
        token: token
      }, status: :created
    else
      render json: { success: false, message: user.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end
  
  def login
    user = User.find_by(email: params[:email])
    
    # Temporary: Allow login with just email for development
    if Rails.env.development? && user
      # Skip password check in development
      token = generate_token(user)
      render json: {
        success: true,
        user: user_response(user),
        token: token
      }
    elsif user&.authenticate(params[:password])
      token = generate_token(user)
      render json: {
        success: true,
        user: user_response(user),
        token: token
      }
    else
      # If user doesn't exist, create one for development
      if Rails.env.development? && params[:email].present?
        user = User.create!(
          email: params[:email],
          password: 'temp123',
          password_confirmation: 'temp123',
          first_name: params[:email].split('@').first.capitalize,
          last_name: 'User',
          plan: 'free'
        )
        
        token = generate_token(user)
        render json: {
          success: true,
          user: user_response(user),
          token: token
        }
      else
        render json: { success: false, message: 'Invalid credentials' }, status: :unauthorized
      end
    end
  end
  
  def logout
    render json: { message: 'Logged out successfully' }
  end
  
  def me
    render json: { user: user_response(current_user) }
  end
  
  def profile
    render json: {
      id: current_user.id,
      email: current_user.email,
      first_name: current_user.first_name,
      last_name: current_user.last_name,
      plan: current_user.plan,
      referral_code: current_user.referral_code,
      referral_link: current_user.referral_link,
      total_referrals: current_user.total_referrals,
      referral_earnings: current_user.referral_earnings,
      profile_data: current_user.profile_data || {}
    }
  end
  
  def update_profile
    begin
      # Update user's profile data in the profile_data JSON field
      profile_fields = params.except(:auth, :controller, :action).permit!
      
      # Store all profile fields in the profile_data JSON field
      current_user.update!(profile_data: profile_fields.to_h)
      
      render json: {
        success: true,
        message: 'Profile updated successfully',
        profile_data: current_user.profile_data
      }
      
    rescue => e
      render json: {
        success: false,
        message: 'Error updating profile',
        error: e.message
      }, status: :internal_server_error
    end
  end

  def parse_resume
    begin
      file_data = params[:fileData] || params[:resumeFile]
      unless file_data.present?
        render json: {
          success: false,
          message: 'Resume file is required'
        }, status: :bad_request
        return
      end

      # Handle both uploaded files and base64 data
      if file_data.is_a?(String) && file_data.start_with?('data:')
        # Base64 encoded file data
        # For now, we'll just process it as valid
        Rails.logger.info "Processing base64 file data: #{file_data[0..100]}..."
      elsif file_data.respond_to?(:read)
        # Uploaded file object
        Rails.logger.info "Processing uploaded file: #{file_data.original_filename}"
      else
        render json: {
          success: false,
          message: 'Invalid file format'
        }, status: :bad_request
        return
      end

      # Extract text from PDF and parse resume data
      begin
        if file_data.is_a?(String) && file_data.start_with?('data:')
          # Decode base64 PDF data
          base64_data = file_data.split(',').last
          pdf_content = Base64.decode64(base64_data)
          
          # For now, extract text using simple parsing (in production, use gems like 'pdf-reader')
          # Try to extract basic info from the PDF metadata/content
          extracted_text = extract_text_from_pdf(pdf_content)
          
          # Parse the extracted text to identify resume components
          parsed_data = parse_resume_text(extracted_text)
        else
          # Fallback for file uploads
          parsed_data = {
            fullName: 'Upload Processing',
            email: 'upload@processing.com',
            phone: '+0000000000',
            skills: 'File upload processing',
            workExperience: [],
            education: []
          }
        end
      rescue => e
        Rails.logger.error "PDF parsing error: #{e.message}"
        # Fallback data if parsing fails
        parsed_data = {
          fullName: 'Parse Error - Manual Entry Required',
          email: 'manual@entry.required',
          phone: '+0000000000',
          skills: 'Please enter manually',
          workExperience: [
            {
              title: 'Previous Role',
              company: 'Previous Company',
              duration: '2020-2024',
              description: 'Please update with your actual experience'
            }
          ],
          education: [
            {
              degree: 'Your Degree',
              school: 'Your University',
              year: '2020'
            }
          ]
        }
      end

      render json: {
        success: true,
        message: 'Resume parsed successfully',
        data: parsed_data
      }
      
    rescue => e
      render json: {
        success: false,
        message: 'Error parsing resume',
        error: e.message
      }, status: :internal_server_error
    end
  end
  
  def customize_resume
    begin
      job_data = params[:jobData]&.to_unsafe_h || {}
      profile_data = (params[:profileData] || params[:resumeData])&.to_unsafe_h || {}
      reference_cv = params[:referenceCV] || nil
      
      if job_data.empty? || profile_data.empty?
        render json: {
          success: false,
          message: 'Job data and profile data are required'
        }, status: :bad_request
        return
      end
      
      # Generate AI-optimized resume content
      customized_content = generate_optimized_resume(job_data, profile_data, reference_cv)
      
      keywords_matched = extract_matched_keywords(job_data, profile_data)
      
      keywords_missing = extract_missing_keywords(job_data, profile_data)
      
      recommendations = generate_recommendations(job_data, profile_data)
      
      render json: {
        success: true,
        message: 'Resume customized successfully',
        customizedContent: customized_content,
        atsScore: 90,
        keywordsMatched: keywords_matched,
        keywordsMissing: keywords_missing,
        recommendations: recommendations
      }
      
    rescue => e
      render json: {
        success: false,
        message: 'Error customizing resume',
        error: e.message
      }, status: :internal_server_error
    end
  end

  def download_pdf
    begin
      html_content = params[:htmlContent]
      
      if html_content.blank?
        render json: {
          success: false,
          message: 'HTML content is required'
        }, status: :bad_request
        return
      end

      # Generate PDF from HTML using wicked_pdf
      pdf = WickedPdf.new.pdf_from_string(
        html_content,
        page_size: 'A4',
        margin: {
          top: '0.5in',
          bottom: '0.5in',
          left: '0.5in',
          right: '0.5in'
        },
        encoding: 'UTF-8',
        print_media_type: true
      )

      # Send PDF as response
      send_data pdf,
                filename: "resume_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'

    rescue => e
      render json: {
        success: false,
        message: 'Error generating PDF',
        error: e.message
      }, status: :internal_server_error
    end
  end

  # Customization history endpoints
  def get_customization_history
    user_id = current_user&.id || 'anonymous'
    user_history = @@customization_history[user_id] || []
    
    render json: {
      success: true,
      history: user_history
    }
  end

  def save_customization_history
    user_id = current_user&.id || 'anonymous'
    
    # Initialize user history if it doesn't exist
    @@customization_history[user_id] ||= []
    
    # Create history entry from request parameters
    history_entry = {
      id: params[:id],
      jobTitle: params[:jobTitle],
      company: params[:company],
      postingUrl: params[:postingUrl],
      atsScore: params[:atsScore],
      keywordsMatched: params[:keywordsMatched] || [],
      keywordsMissing: params[:keywordsMissing] || [],
      resumeContent: params[:resumeContent],
      timestamp: params[:timestamp] || Time.current.iso8601,
      profileSnapshot: params[:profileSnapshot] || {}
    }
    
    # Add to user's history (keep last 50 entries)
    @@customization_history[user_id].unshift(history_entry)
    @@customization_history[user_id] = @@customization_history[user_id].first(50)
    
    render json: {
      success: true,
      message: 'Customization history saved',
      entry: history_entry
    }
  end

  def delete_customization_history
    user_id = current_user&.id || 'anonymous'
    entry_id = params[:id]
    
    if @@customization_history[user_id]
      @@customization_history[user_id].reject! { |entry| entry[:id] == entry_id }
    end
    
    render json: {
      success: true,
      message: 'Customization history deleted'
    }
  end

  def download_history_pdf
    user_id = current_user&.id || 'anonymous'
    entry_id = params[:id]
    
    # Find the history entry
    user_history = @@customization_history[user_id] || []
    history_entry = user_history.find { |entry| entry[:id] == entry_id }
    
    if history_entry.nil?
      render json: {
        success: false,
        message: 'Resume not found in history'
      }, status: :not_found
      return
    end
    
    begin
      # Get the HTML content from the history entry
      html_content = history_entry[:resumeContent]
      
      if html_content.blank?
        render json: {
          success: false,
          message: 'Resume content not available'
        }, status: :bad_request
        return
      end

      # Generate PDF from HTML using wicked_pdf
      pdf = WickedPdf.new.pdf_from_string(
        html_content,
        page_size: 'A4',
        margin: {
          top: '0.5in',
          bottom: '0.5in',
          left: '0.5in',
          right: '0.5in'
        },
        encoding: 'UTF-8',
        print_media_type: true
      )

      # Send PDF as response
      send_data pdf,
                filename: "resume_#{entry_id}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'
    rescue => e
      render json: {
        success: false,
        message: 'Error generating PDF from history',
        error: e.message
      }, status: :internal_server_error
    end
  end

  # Coin management endpoints
  def coin_balance
    render json: {
      success: true,
      balance: 100,
      free_credits: 10
    }
  end

  def coin_transactions
    render json: {
      success: true,
      transactions: []
    }
  end

  private

  def generate_optimized_resume(job_data, profile_data, reference_cv = nil)
    # Extract user's actual skills with strict filtering
    
    user_skills = begin
      # Safely get skills data with proper handling
      skills_data = profile_data[:skills] || profile_data['skills'] || []
      
      if skills_data.is_a?(Array)
        skills_data.compact.map { |s| s.to_s.strip }.reject(&:blank?)
      else
        skills_data.to_s.split(',').map(&:strip).reject(&:blank?)
      end
    rescue => e
      Rails.logger.error "Error extracting skills: #{e.message}"
      []  # return empty array on error
    end
    
    # Ensure user_skills is not empty, use default if needed
    user_skills = ['Professional Experience'] if user_skills.empty?
    
    # Only include skills user actually has - NO random additions
    filtered_skills = filter_user_skills_only(user_skills, job_data)
    
    # Generate professional resume HTML
    generate_professional_resume_html(profile_data, job_data, filtered_skills)
  end
  
  def filter_user_skills_only(user_skills, job_data)
    job_description = job_data[:description] || job_data['description'] || ''
    
    # Use AI to intelligently match and prioritize skills
    begin
      openai_service = OpenaiService.new
      ai_optimized_skills = openai_service.analyze_and_optimize_skills(user_skills, job_description)
      return ai_optimized_skills unless ai_optimized_skills.empty?
    rescue => e
      Rails.logger.error "Error with AI skills optimization: #{e.message}"
      # Fall back to manual filtering
    end
    
    # Fallback: Start with user's actual skills (formatted properly)
    filtered_skills = user_skills.compact.map { |skill| format_skill_name(skill.to_s.strip) }.uniq
    
    # Add job requirements that user has, but avoid vague/ambiguous terms
    job_requirements = extract_job_skills_from_description(job_description)
    
    job_requirements.each do |job_skill|
      # Check if user has this skill with precise matching to avoid false positives
      user_has_skill = user_skills.compact.any? do |user_skill|
        user_clean = user_skill.to_s.downcase.strip
        job_clean = job_skill.to_s.downcase.strip
        
        # Exact match
        user_clean == job_clean ||
        # Handle specific common variations
        (job_clean == 'react.js' && user_clean == 'react') ||
        (job_clean == 'node.js' && (user_clean == 'node' || user_clean == 'nodejs')) ||
        (job_clean == 'javascript' && (user_clean == 'js' || user_clean == 'javascript')) ||
        (job_clean == 'html5' && user_clean == 'html') ||
        (job_clean == 'css3' && user_clean == 'css') ||
        (job_clean == 'postgresql' && (user_clean == 'postgres' || user_clean == 'postgresql'))
      end
      
      if user_has_skill && !is_vague_technology(job_skill)
        formatted_skill = format_skill_name(job_skill)
        filtered_skills << formatted_skill unless filtered_skills.include?(formatted_skill)
      end
    end
    
    filtered_skills.uniq
  end
  
  def extract_job_skills_from_description(description)
    # Extract technical skills from job description
    common_skills = [
      'React.js', 'Vue.js', 'Angular', 'JavaScript', 'TypeScript', 'HTML5', 'CSS3',
      'Node.js', 'Express.js', 'Python', 'Django', 'Flask', 'FastAPI', 'Java', 
      'Spring Boot', 'Ruby on Rails', 'PHP', 'Laravel', '.NET', 'C#',
      'PostgreSQL', 'MySQL', 'MongoDB', 'Redis', 'Elasticsearch', 'SQLite',
      'AWS', 'Docker', 'Kubernetes', 'Jenkins', 'GitLab CI', 'GitHub Actions',
      'Terraform', 'Ansible', 'Azure', 'Google Cloud Platform', 'Git', 'GitHub',
      'Jest', 'Cypress', 'Selenium', 'JUnit', 'pytest', 'GraphQL', 'REST API',
      'Microservices', 'Agile', 'Scrum', 'CI/CD', 'TDD', 'BDD'
    ]
    
    found_skills = []
    common_skills.each do |skill|
      if description.downcase.include?(skill.downcase)
        found_skills << skill
      end
    end
    
    found_skills
  end
  
  def is_vague_technology(skill)
    # Avoid adding vague, single-letter, or ambiguous technology names
    vague_terms = ['go', 'r', 'c', 'swift', 'rust', 'dart', 'scala', 'kotlin', 'perl']
    vague_terms.include?(skill.downcase.strip)
  end
  
  def format_skill_name(skill)
    # Convert common skill names to their proper explicit versions for ATS
    case skill.downcase.strip
    when 'react'
      'React.js'
    when 'node', 'nodejs'
      'Node.js'
    when 'js'
      'JavaScript'
    when 'postgres'
      'PostgreSQL'
    else
      skill.strip
    end
  end
  
  def generate_professional_resume_html(profile_data, job_data, skills)
    skills_text = skills.join(', ')
    
    <<~HTML
      <div class="resume professional-reference-style">
        <div class="header-section">
          <h1 class="candidate-name">#{profile_data[:fullName] || profile_data['fullName'] || profile_data[:name] || profile_data['name']}</h1>
          <h2 class="job-title">#{job_data[:title] || job_data['title']}</h2>
          <div class="contact-line">Email: #{profile_data[:email] || profile_data['email']} | LinkedIn: linkedin.com/in/#{((profile_data[:fullName] || profile_data['fullName'] || profile_data[:name] || profile_data['name']) || '').to_s.downcase.gsub(' ', '')} | Phone: #{profile_data[:phone] || profile_data['phone']} | Location: #{profile_data[:address] || profile_data['address']}</div>
          <div class="blue-divider"></div>
        </div>
        <div class="professional-summary-box">
          <p class="summary-text">#{generate_professional_summary(profile_data, job_data)}</p>
        </div>
        <section class="core-skills-section">
          <h3>Core Skills</h3>
          <p class="skills-text">#{skills_text}</p>
        </section>
        <section class="experience-section">
          <h3>Professional Experience</h3>
          #{generate_work_experience(profile_data, job_data)}
        </section>
        <section class="education-section">
          <h3>Education</h3>
          #{generate_education_section(profile_data)}
        </section>
        <section class="languages-section">
          <h3>Languages</h3>
          <p>English (Fluent)</p>
        </section>
      </div>
    HTML
  end
  
  def generate_professional_summary(profile_data, job_data)
    # Use OpenAI for intelligent summary generation
    openai_service = OpenaiService.new
    openai_service.generate_professional_summary(profile_data, job_data)
  rescue => e
    Rails.logger.error "Error generating AI summary: #{e.message}"
    # Fallback to static summary if AI fails
    experience = profile_data[:workExperience] || profile_data['workExperience'] || []
    current_role = experience.first
    
    if current_role
      "#{current_role['designation'] || 'Software Developer'} with #{calculate_experience_years(experience)}+ years of experience in developing applications using proven technologies. Successfully contributed to multiple projects at #{current_role['company'] || 'Previous Company'}, delivering quality solutions. Seeking to leverage expertise to contribute to #{job_data[:company] || job_data['company']}'s success as a #{job_data[:title] || job_data['title']}."
    else
      "Experienced professional seeking to contribute technical expertise to #{job_data[:company] || job_data['company']}'s success as a #{job_data[:title] || job_data['title']}."
    end
  end
  
  def calculate_experience_years(experience)
    return 3 if experience.empty?
    
    # Simple calculation based on first role
    first_role = experience.first
    duration = first_role['duration'] || '2021-2024'
    years = duration.split('-').map(&:to_i)
    years.length >= 2 ? (years.last - years.first).abs : 3
  end
  
  def generate_work_experience(profile_data, job_data)
    experience = profile_data[:workExperience] || profile_data['workExperience'] || []
    
    if experience.empty?
      return "<p>No work experience provided</p>"
    end
    
    experience.map do |exp|
      <<~HTML
        <div class="experience-entry">
          <h4 class="position-title">#{exp['title']}</h4>
          <p class="company-name">#{exp['company']} | #{profile_data[:location] || profile_data['location'] || 'Location'}</p>
          <p class="employment-duration">#{exp['duration']}</p>
          <ul class="achievements-list">
            #{generate_achievement_bullets(exp, job_data)}
          </ul>
        </div>
      HTML
    end.join("\n")
  end
  
  def generate_achievement_bullets(experience, job_data)
    # Use AI to generate tailored achievement bullets
    job_description = job_data[:description] || job_data['description'] || ''
    
    begin
      openai_service = OpenaiService.new
      ai_description = openai_service.rewrite_work_experience(experience, job_description)
      
      if ai_description.present?
        # Parse AI-generated bullets (should be formatted as bullet points)
        bullets = ai_description.split(/\n|•|·|-/).map(&:strip).reject(&:blank?)
        return bullets.map { |bullet| "<li>#{bullet}</li>" }.join("\n            ") if bullets.any?
      end
    rescue => e
      Rails.logger.error "Error generating AI achievement bullets: #{e.message}"
    end
    
    # Fallback to static bullets if AI fails
    bullets = [
      "Successfully delivered multiple projects using core technologies, improving efficiency by 25%.",
      "Collaborated with cross-functional teams to implement solutions that enhanced user experience.", 
      "Participated in code reviews and maintained high-quality coding standards.",
      "Contributed to project planning and delivered features on time within agile methodology.",
      "Optimized application performance and resolved technical issues to ensure system reliability."
    ]
    
    bullets.map { |bullet| "<li>#{bullet}</li>" }.join("\n            ")
  end
  
  def generate_education_section(profile_data)
    education = profile_data[:education] || profile_data['education'] || []
    
    if education.blank?
      return "<p>Education details not provided</p>"
    end
    
    # Handle different education data formats
    if education.is_a?(String)
      # Simple string format like "Bcom"
      return "<p>#{education}</p>"
    elsif education.is_a?(Array)
      # Array of education objects
      education.map do |edu|
        if edu.is_a?(String)
          "<p>#{edu}</p>"
        else
          # Hash format
          degree = edu[:degree] || edu['degree'] || 'Degree not specified'
          school = edu[:school] || edu['school'] || 'School not specified'
          year = edu[:year] || edu['year'] || 'Year not specified'
          "<p>#{degree}, #{school}, #{year}</p>"
        end
      end.join("\n          ")
    else
      # Hash format
      degree = education[:degree] || education['degree'] || 'Degree not specified'
      school = education[:school] || education['school'] || 'School not specified'
      year = education[:year] || education['year'] || 'Year not specified'
      "<p>#{degree}, #{school}, #{year}</p>"
    end
  end
  
  def extract_matched_keywords(job_data, profile_data)
    user_skills = if profile_data[:skills].is_a?(Array)
                   profile_data[:skills].compact.reject(&:blank?)
                 elsif profile_data['skills'].is_a?(Array)
                   profile_data['skills'].compact.reject(&:blank?)
                 else
                   skills_str = profile_data[:skills] || profile_data['skills'] || ''
                   skills_str.to_s.split(',').map(&:strip).reject(&:blank?)
                 end
    
    # Return skills that user actually has (formatted properly)
    return [] if user_skills.empty?
    user_skills.compact.map { |skill| format_skill_name(skill.to_s) }
  end
  
  def extract_missing_keywords(job_data, profile_data)
    job_description = job_data[:description] || job_data['description'] || ''
    user_skills = if profile_data[:skills].is_a?(Array)
                   profile_data[:skills].compact.map { |s| s.to_s.downcase }.reject(&:blank?)
                 elsif profile_data['skills'].is_a?(Array)
                   profile_data['skills'].compact.map { |s| s.to_s.downcase }.reject(&:blank?)
                 else
                   skills_str = profile_data[:skills] || profile_data['skills'] || ''
                   skills_str.to_s.downcase.split(',').map(&:strip).reject(&:blank?)
                 end
    
    # Common job requirements that user might not have
    common_requirements = ['Docker', 'Kubernetes', 'AWS', 'MongoDB', 'Redis', 'TypeScript', 'GraphQL']
    missing = []
    
    common_requirements.each do |req|
      if job_description.downcase.include?(req.downcase) && !user_skills.any? { |skill| skill.to_s.downcase.include?(req.downcase) }
        missing << req
      end
    end
    
    missing
  end
  
  def generate_recommendations(job_data, profile_data)
    missing = extract_missing_keywords(job_data, profile_data)
    recommendations = []
    
    if missing.any?
      recommendations << "Consider gaining experience in #{missing.first(2).join(' and ')} to align more closely with job requirements."
    end
    
    recommendations << "Highlight specific achievements and metrics to demonstrate impact."
    recommendations.empty? ? ["Great match! Your skills align well with the job requirements."] : recommendations
  end
  
  def user_params
    # Accept both nested and non-nested parameter formats
    if params[:user]
      params.require(:user).permit(:email, :password, :first_name, :last_name)
    else
      params.permit(:email, :password, :first_name, :last_name)
    end
  end
  
  def user_response(user)
    {
      id: user.id,
      email: user.email,
      first_name: user.first_name,
      last_name: user.last_name,
      plan: user.plan,
      dm_usage: "#{user.current_month_dm_count}/#{user.dm_limit}",
      contact_usage: "#{user.current_month_contact_count}/#{user.contact_limit}"
    }
  end


  # Download endpoints

  def download_doc
    begin
      html_content = params[:htmlContent]
      if html_content.blank?
        render json: {
          success: false,
          message: 'HTML content is required'
        }, status: :bad_request
        return
      end

      # For now, return a simple response
      render json: {
        success: true,
        message: 'DOC generation endpoint - implement with DOC library',
        downloadUrl: 'data:text/plain;base64,' + Base64.encode64("Resume DOC content")
      }
    rescue => e
      render json: {
        success: false,
        message: 'Error generating DOC',
        error: e.message
      }, status: :internal_server_error
    end
  end

  # PDF text extraction using pdf-reader gem
  def extract_text_from_pdf(pdf_content)
    require 'pdf-reader'
    
    # Use PDF::Reader for robust text extraction
    text = ''
    
    begin
      # Write PDF content to a temporary file
      temp_file = Tempfile.new(['resume', '.pdf'])
      temp_file.binmode
      temp_file.write(pdf_content)
      temp_file.close
      
      # Read PDF using pdf-reader gem
      PDF::Reader.open(temp_file.path) do |reader|
        reader.pages.each do |page|
          page_text = page.text.strip
          text += page_text + "\n" unless page_text.empty?
        end
      end
      
    rescue PDF::Reader::MalformedPDFError => e
      Rails.logger.error "Malformed PDF: #{e.message}"
      # Fallback to basic text extraction
      text = extract_text_basic(pdf_content)
    rescue => e
      Rails.logger.error "PDF reading error: #{e.message}"
      # Fallback to basic text extraction
      text = extract_text_basic(pdf_content)
    ensure
      # Clean up temporary file
      temp_file&.unlink
    end
    
    # Clean and normalize text
    text.gsub(/\s+/, ' ').strip
  end
  
  # Fallback basic text extraction
  def extract_text_basic(pdf_content)
    text = ''
    
    # Look for PDF text content patterns
    if pdf_content.include?('stream')
      text_matches = pdf_content.scan(/stream\s*(.*?)\s*endstream/m)
      text = text_matches.join(' ')
    end
    
    # Clean extracted text
    text.gsub(/[^\x20-\x7E]/, ' ').squeeze(' ').strip
  rescue => e
    Rails.logger.error "Basic text extraction error: #{e.message}"
    ''
  end

  # Parse extracted text to identify resume components
  def parse_resume_text(text)
    Rails.logger.info "Parsing text of length: #{text.length}"
    Rails.logger.info "First 200 characters: #{text[0..200]}" if text.length > 0
    
    # If no meaningful text extracted, provide user-friendly placeholders
    if text.blank? || text.length < 50
      Rails.logger.info "PDF appears to be image-based or text extraction failed. Using smart defaults."
      return {
        fullName: 'Unable to extract from PDF - Please enter manually',
        email: 'your.email@example.com',
        phone: '+91-XXXX-XXXX',
        skills: 'PDF text extraction failed - please enter your skills manually',
        workExperience: [
          {
            title: 'Your Job Title',
            company: 'Company Name',
            duration: 'Start Date - End Date',
            description: 'Unable to extract work experience from PDF - please enter manually'
          }
        ],
        education: [
          {
            degree: 'Your Degree',
            school: 'University Name',
            year: 'Graduation Year'
          }
        ]
      }
    end
    
    # Extract information from the text
    email = extract_email(text)
    phone = extract_phone(text)
    name = extract_name(text)
    skills = extract_skills(text)
    work_experience = extract_work_experience(text)
    education = extract_education(text)
    
    Rails.logger.info "Extracted name: #{name}, email: #{email}, phone: #{phone}"
    
    {
      fullName: name.present? ? name : 'Name not found in PDF - Please enter manually',
      email: email.present? ? email : 'email@example.com',
      phone: phone.present? ? phone : '+91-XXXX-XXXX',
      skills: skills,
      workExperience: work_experience,
      education: education
    }
  end

  def extract_email(text)
    # Improved email regex that handles more cases
    email_regex = /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/
    matches = text.scan(email_regex)
    
    # Return the first valid email found
    valid_email = matches.find do |email|
      # Exclude common placeholder emails
      !email.downcase.include?('example.com') &&
      !email.downcase.include?('test.com') &&
      !email.downcase.include?('sample.com')
    end
    
    valid_email
  end

  def extract_phone(text)
    # Multiple phone number patterns
    patterns = [
      /\+?91[-.\s]?\d{10}/,  # Indian format: +91 XXXXXXXXXX
      /\+?1[-.\s]?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/, # US format
      /\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}/, # General format
      /\d{10}/, # Simple 10-digit number
      /\+\d{1,3}[-.\s]?\d{8,12}/ # International format
    ]
    
    patterns.each do |pattern|
      match = text.match(pattern)
      if match
        phone = match[0]
        # Clean and format phone number
        cleaned = phone.gsub(/[^\d+]/, '')
        return phone if cleaned.length >= 10
      end
    end
    
    nil
  end

  def extract_name(text)
    lines = text.split(/[\r\n]+/).map(&:strip).reject(&:empty?)
    
    # Look for name in the first few lines
    potential_names = lines.first(5).select do |line|
      # Filter potential name lines
      line.length.between?(5, 50) &&
      !line.include?('@') &&
      !line.include?('http') &&
      !line.downcase.include?('resume') &&
      !line.downcase.include?('curriculum') &&
      !line.downcase.include?('cv') &&
      line.split.length.between?(2, 4) &&
      # Check if line contains mostly alphabetic characters
      line.gsub(/[^a-zA-Z]/, '').length > line.length * 0.6
    end
    
    # Return the first suitable name found
    name = potential_names.first
    
    # If no name found in first lines, try to find it near 'name' keyword
    if name.nil?
      text_lines = text.split(/[\r\n]+/)
      name_line_idx = text_lines.find_index { |line| line.downcase.include?('name') }
      if name_line_idx
        # Look for name in the same line or next few lines
        (name_line_idx..name_line_idx+2).each do |idx|
          next unless text_lines[idx]
          
          line = text_lines[idx]
          # Extract name after 'name:' or similar patterns
          if line.match(/name\s*:?\s*([a-zA-Z\s]+)/i)
            extracted = $1.strip
            if extracted.split.length.between?(2, 4)
              name = extracted
              break
            end
          end
        end
      end
    end
    
    name&.titleize
  end

  def extract_skills(text)
    # Comprehensive technology and skill keywords
    tech_keywords = [
      # Programming Languages
      'JavaScript', 'TypeScript', 'Python', 'Java', 'C++', 'C#', 'PHP', 'Ruby', 'Swift', 'Kotlin', 'Go', 'Rust',
      # Frontend Frameworks/Libraries
      'React', 'React.js', 'Angular', 'Vue', 'Vue.js', 'jQuery', 'Svelte',
      # Backend Frameworks
      'Node.js', 'Express', 'Django', 'Flask', 'FastAPI', 'Spring', 'Spring Boot', 'Rails', 'Laravel', 'ASP.NET',
      # Databases
      'MongoDB', 'PostgreSQL', 'MySQL', 'Redis', 'Elasticsearch', 'SQLite', 'Oracle', 'SQL Server',
      # Cloud & DevOps
      'AWS', 'Azure', 'Google Cloud', 'GCP', 'Docker', 'Kubernetes', 'Jenkins', 'GitLab CI', 'GitHub Actions',
      # Web Technologies
      'HTML', 'HTML5', 'CSS', 'CSS3', 'SASS', 'SCSS', 'Bootstrap', 'Tailwind',
      # Tools & Platforms
      'Git', 'GitHub', 'GitLab', 'Bitbucket', 'Jira', 'Confluence', 'Slack',
      # Testing
      'Jest', 'Cypress', 'Selenium', 'JUnit', 'pytest', 'Mocha', 'Chai',
      # APIs & Architecture
      'REST', 'REST API', 'GraphQL', 'Microservices', 'API Gateway',
      # Methodologies
      'Agile', 'Scrum', 'Kanban', 'CI/CD', 'TDD', 'BDD'
    ]
    
    # Find skills in the text (case-insensitive)
    found_skills = []
    
    # Look for skills section specifically
    skills_section = extract_skills_section(text)
    if skills_section.present?
      tech_keywords.each do |skill|
        if skills_section.downcase.include?(skill.downcase)
          found_skills << skill unless found_skills.include?(skill)
        end
      end
    else
      # Search throughout the entire text
      tech_keywords.each do |skill|
        if text.downcase.include?(skill.downcase)
          found_skills << skill unless found_skills.include?(skill)
        end
      end
    end
    
    # Remove duplicates and format
    found_skills = found_skills.uniq.sort
    
    found_skills.any? ? found_skills.join(', ') : 'Please add your technical skills from the PDF manually'
  end
  
  def extract_skills_section(text)
    # Try to find skills section in the resume
    lines = text.split(/[\r\n]+/)
    skills_start = nil
    
    # Find the start of skills section
    lines.each_with_index do |line, idx|
      if line.downcase.match?(/^\s*(skills|technical skills|core skills|technologies|competencies)/)
        skills_start = idx
        break
      end
    end
    
    return nil unless skills_start
    
    # Extract text from skills section until next section
    skills_lines = []
    (skills_start + 1...lines.length).each do |idx|
      line = lines[idx].strip
      
      # Stop if we hit another section header
      if line.downcase.match?(/^\s*(experience|education|projects|certifications|awards|languages)/)
        break
      end
      
      skills_lines << line unless line.empty?
    end
    
    skills_lines.join(' ')
  end

  def extract_work_experience(text)
    experiences = []
    lines = text.split(/[\r\n]+/).map(&:strip).reject(&:empty?)
    
    # Find experience section
    exp_start = nil
    lines.each_with_index do |line, idx|
      if line.downcase.match?(/^\s*(experience|work experience|employment|professional experience|career)/)
        exp_start = idx
        break
      end
    end
    
    if exp_start
      # Extract experience entries
      current_exp = {}
      
      (exp_start + 1...lines.length).each do |idx|
        line = lines[idx]
        
        # Stop if we hit another section
        if line.downcase.match?(/^\s*(education|skills|projects|certifications|awards)/)
          break
        end
        
        # Try to identify job title and company patterns
        if line.match?(/^[A-Za-z].+\s+at\s+.+/i) || line.match?(/^[A-Za-z].+\s+-\s+.+/i)
          # Save previous experience if exists
          experiences << current_exp if current_exp[:title]
          
          parts = line.split(/\s+at\s+|\s+-\s+/i)
          current_exp = {
            title: parts[0]&.strip,
            company: parts[1]&.strip,
            duration: 'Please update duration',
            description: 'Please update job description'
          }
        elsif line.match?(/\d{4}.*\d{4}|\d{4}.*present|\d{4}.*current/i)
          # Duration line
          current_exp[:duration] = line if current_exp[:title]
        elsif line.length > 20 && current_exp[:title] && !line.match?(/^[A-Z][a-z]+\s+[A-Z]/)
          # Description line (not another job title)
          current_exp[:description] = line
        end
      end
      
      # Add last experience
      experiences << current_exp if current_exp[:title]
    end
    
    # Return default if no experiences found
    if experiences.empty?
      experiences = [
        {
          title: 'Previous Role (Update from PDF)',
          company: 'Company Name (Update from PDF)',
          duration: 'Start Date - End Date',
          description: 'Job description not automatically extracted - please review your PDF and update manually'
        }
      ]
    end
    
    experiences
  end

  def extract_education(text)
    education_entries = []
    lines = text.split(/[\r\n]+/).map(&:strip).reject(&:empty?)
    
    # Find education section
    edu_start = nil
    lines.each_with_index do |line, idx|
      if line.downcase.match?(/^\s*(education|academic|qualifications|degrees)/)
        edu_start = idx
        break
      end
    end
    
    if edu_start
      current_edu = {}
      
      (edu_start + 1...lines.length).each do |idx|
        line = lines[idx]
        
        # Stop if we hit another section
        if line.downcase.match?(/^\s*(experience|skills|projects|certifications|work)/)
          break
        end
        
        # Look for degree patterns
        if line.match?(/bachelor|master|phd|doctorate|diploma|certificate|b\.|m\.|bsc|msc|ba|ma|be|me|btech|mtech/i)
          # Save previous education if exists
          education_entries << current_edu if current_edu[:degree]
          
          current_edu = {
            degree: line.strip,
            school: 'University name not found',
            year: 'Year not specified'
          }
        elsif line.match?(/university|college|institute|school/i) && current_edu[:degree]
          current_edu[:school] = line.strip
        elsif line.match?(/\d{4}/) && current_edu[:degree]
          # Extract year
          year_match = line.match(/(\d{4})/)
          current_edu[:year] = year_match[1] if year_match
        end
      end
      
      # Add last education entry
      education_entries << current_edu if current_edu[:degree]
    end
    
    # Return default if no education found
    if education_entries.empty?
      education_entries = [
        {
          degree: 'Degree information not extracted - please update from PDF',
          school: 'University name not found - please update',
          year: 'Year not specified'
        }
      ]
    end
    
    education_entries
  end
end