class AiController < ApplicationController
  OPENAI_API_KEY = ENV['OPENAI_API_KEY']
  COINS_PER_CUSTOMIZATION = 10
  
  def customize
    unless current_user.deduct_coins(COINS_PER_CUSTOMIZATION, 'AI resume customization')
      return render_error('Insufficient coins. You need 10 coins for AI customization.')
    end
    
    begin
      # Get parameters
      resume_data = params[:resumeData]
      job_data = params[:jobData]
      
      # Call OpenAI API
      raw_response = call_openai_api(resume_data, job_data)
      
      # Clean the response - remove markdown code blocks if present
      customized_resume = clean_html_response(raw_response)
      
      # Calculate ATS score and keywords
      ats_analysis = analyze_ats_compatibility(customized_resume, job_data)
      
      # Save customization history
      customization = current_user.customizations.create!(
        job_title: job_data[:title] || 'Unknown Job',
        company: job_data[:company] || 'Unknown Company',
        posting_url: job_data[:url],
        platform: job_data[:platform] || 'unknown',
        ats_score: ats_analysis[:score],
        keywords_matched: ats_analysis[:matched],
        keywords_missing: ats_analysis[:missing],
        resume_content: customized_resume,
        profile_snapshot: resume_data
      )
      
      render_success({
        customizedContent: customized_resume,
        atsScore: ats_analysis[:score],
        keywordsMatched: ats_analysis[:matched],
        keywordsMissing: ats_analysis[:missing],
        customizationId: customization.id
      })
      
    rescue => e
      # Refund coins on error
      current_user.add_coins(COINS_PER_CUSTOMIZATION, 'Refund for failed customization')
      render_error("AI customization failed: #{e.message}")
    end
  end
  
  def ats_score
    resume_content = params[:resumeContent]
    job_requirements = params[:jobRequirements]
    
    analysis = analyze_ats_compatibility(resume_content, job_requirements)
    
    render_success({
      atsScore: analysis[:score],
      keywordsMatched: analysis[:matched],
      keywordsMissing: analysis[:missing],
      suggestions: analysis[:suggestions]
    })
  end
  
  private

  def clean_html_response(response)
    # Remove markdown code blocks if present
    cleaned = response.gsub(/```html\s*/, '').gsub(/```\s*$/, '').strip
    
    # Extract just the HTML content between <body> tags if it's a full HTML document
    if cleaned.include?('<body>')
      body_match = cleaned.match(/<body[^>]*>(.*?)<\/body>/m)
      if body_match
        # Return just the body content
        return body_match[1].strip
      end
    end
    
    # If it's already clean HTML without full document structure, return as is
    cleaned
  end
  
  def call_openai_api(resume_data, job_data)
    system_prompt = build_system_prompt
    user_prompt = build_user_prompt(resume_data, job_data)
    
    response = HTTParty.post(
      'https://api.openai.com/v1/chat/completions',
      headers: {
        'Authorization' => "Bearer #{OPENAI_API_KEY}",
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: user_prompt }
        ],
        max_tokens: 8000,
        temperature: 0.7
      }.to_json
    )
    
    if response.success?
      response.dig('choices', 0, 'message', 'content')
    else
      raise "OpenAI API error: #{response.body}"
    end
  end
  
  def build_system_prompt
    <<~PROMPT
      You are an advanced ATS optimization specialist and resume writer with expertise in job market analysis. Your task is to intelligently transform resumes for specific job postings using sophisticated keyword optimization and role-specific customization.

      CORE OBJECTIVES:
      1. Extract and strategically integrate job-specific keywords for maximum ATS score
      2. Rewrite the professional summary to directly address the job requirements
      3. Optimize and expand core skills section with role-relevant technologies and competencies
      4. Generate 5-6 highly specific, results-oriented job responsibilities for each role
      5. Use industry-standard terminology and phrases that ATS systems recognize
      6. Maintain authenticity while maximizing keyword density and relevance

      ATS OPTIMIZATION STRATEGY:
      - Analyze job posting for critical keywords, skills, and requirements
      - Mirror job posting language and terminology in resume content
      - Include both technical skills and soft skills mentioned in job requirements
      - Use variations of keywords (e.g., "management", "managing", "manager")
      - Incorporate industry buzzwords and modern terminology
      - Ensure keywords appear naturally in context, not just as lists

      CONTENT ENHANCEMENT RULES:
      - Professional Summary: Rewrite to directly address the specific job role with 4-5 sentences that mirror job requirements
      - Core Skills: Add relevant skills from job posting while keeping existing skills, prioritize job-relevant ones first
      - Job Responsibilities: Generate 5-6 detailed, quantifiable achievements per role that align with target job requirements
      - Use strong action verbs: led, optimized, implemented, achieved, increased, reduced, developed, managed
      - Include metrics and percentages where logical (but don't fabricate specific numbers)

      OUTPUT FORMAT: Return clean HTML content with professional blue accent design:
      
      HEADER STRUCTURE (Professional Blue Theme):
      - Header container: <div class="resume-header">
      - Centered name: <h1 class="resume-name">FULL NAME</h1>
      - Job title in blue: <div class="job-title-blue">CURRENT ROLE/TITLE</div>
      - Contact line: <div class="contact-line">Email: email | LinkedIn: url | Phone: phone | Location: address</div>
      - Blue accent line: <div class="blue-accent-line"></div>
      - Professional summary in blue sidebar: <div class="summary-sidebar"><p>Summary text...</p></div>
      
      SECTION STRUCTURE:
      - Section headers: <h2>SECTION NAME</h2>
      - Work experience format:
        <h3>Job Title</h3>
        <div class="company-line">Company Name | City, State</div>
        <div class="job-dates">Start Date - End Date</div>
        <ul><li>Achievement 1</li><li>Achievement 2</li>...</ul>
      
      - Skills as comma-separated text: <div class="skills-list">Skill1, Skill2, Skill3...</div>
      - Education: <div class="education-item"><strong>User's Education</strong></div>
      - Languages: <div class="languages">Language1, Language2, Language3...</div>
      
      ATS REQUIREMENTS:
      - Use standard HTML tags only: h1, h2, h3, p, div, ul, li, strong
      - No complex layouts, tables, or graphics
      - Include specific CSS classes: contact-info, summary, company-line, job-dates, skills-list, education-item, languages
      - Use simple, linear structure that ATS can easily parse
      - Separate content clearly with proper spacing
      
      CRITICAL: 
      - Transform content to match the job requirements while keeping all factual information accurate
      - Use ONLY the education information provided by the user - do NOT add university names or institutions
      - Use ONLY the languages provided by the user exactly as given - do NOT add fluency levels, proficiency indicators, or any additional text
      - Keep Technical Skills and Languages completely separate - do NOT mix skills with languages
      - Return ONLY the HTML content for the resume sections
      - Do NOT include any explanatory text or AI-generated footer messages
      - Do NOT add any meta-commentary about the customization process
    PROMPT
  end
  
  def build_user_prompt(resume_data, job_data)
    <<~PROMPT
      TRANSFORMATION TASK: Create an ATS-optimized resume specifically tailored for this job posting.

      TARGET JOB POSTING:
      Position: #{job_data[:title]}
      Company: #{job_data[:company]}
      Job Description: #{job_data[:description]}
      Key Requirements: #{job_data[:requirements]}

      CURRENT CANDIDATE PROFILE:
      Name: #{resume_data[:name]}
      Email: #{resume_data[:email]}
      Phone: #{resume_data[:phone]}
      LinkedIn: #{resume_data[:linkedin_url] || resume_data[:linkedin]}
      Address: #{resume_data[:address]}
      Current Role: #{resume_data[:designation]}
      Current Summary: #{resume_data[:summary]}
      
      Technical Skills: #{resume_data[:skills]&.join(', ')}
      Languages: #{resume_data[:languages]&.join(', ')}
      
      Professional Experience:
      #{format_work_experience(resume_data[:workExperience] || resume_data[:workExperiences])}
      
      Education: #{resume_data[:education]}
      Certifications: #{resume_data[:certificates]&.join(', ')}

      OPTIMIZATION REQUIREMENTS:
      1. ANALYZE the job posting to extract critical keywords, required skills, and key responsibilities
      2. REWRITE the professional summary to directly address this specific job role and requirements
      3. OPTIMIZE the skills section by adding relevant technologies and competencies mentioned in the job posting
      4. ENHANCE each work experience with 5-6 specific, results-oriented responsibilities that align with the target role
      5. INTEGRATE job-specific terminology and keywords naturally throughout the content
      6. MAINTAIN factual accuracy while maximizing relevance and ATS compatibility

      Generate a comprehensive, keyword-rich resume that positions this candidate as the ideal fit for the specified role.
    PROMPT
  end
  
  def format_work_experience(experiences)
    return 'None' unless experiences&.any?
    
    experiences.map do |exp|
      # Format dates - use startDate/endDate if available, otherwise use duration
      date_range = if exp[:startDate] && exp[:endDate] && !exp[:endDate].empty?
                     "#{exp[:startDate]} to #{exp[:endDate]}"
                   elsif exp[:startDate] && exp[:current]
                     "#{exp[:startDate]} to Present"
                   elsif exp[:startDate]
                     "#{exp[:startDate]} to Present"
                   elsif exp[:duration]
                     exp[:duration]
                   else
                     "Date not specified"
                   end
      
      <<~EXP
        #{exp[:designation]} at #{exp[:company]} (#{date_range})
        #{exp[:description]}
      EXP
    end.join("\n")
  end
  
  def analyze_ats_compatibility(resume_content, job_data)
    # Extract keywords from job posting
    job_keywords = extract_keywords_from_job(job_data)
    resume_text = strip_html(resume_content).downcase
    
    matched_keywords = []
    missing_keywords = []
    
    job_keywords.each do |keyword|
      if resume_text.include?(keyword.downcase)
        matched_keywords << keyword
      else
        missing_keywords << keyword
      end
    end
    
    # Calculate ATS score
    score = job_keywords.any? ? (matched_keywords.length.to_f / job_keywords.length * 100).round : 0
    
    {
      score: score,
      matched: matched_keywords,
      missing: missing_keywords.first(5), # Top 5 missing keywords
      suggestions: generate_suggestions(missing_keywords)
    }
  end
  
  def extract_keywords_from_job(job_data)
    # Combine all job text
    job_text = "#{job_data[:title]} #{job_data[:description]} #{job_data[:requirements]}".downcase
    
    # Comprehensive ATS keywords categorized by domain
    technical_skills = %w[
      python javascript typescript react angular vue node express
      sql mysql postgresql mongodb redis elasticsearch
      aws azure gcp docker kubernetes terraform ansible
      git github gitlab jenkins ci/cd devops microservices
      api rest graphql json xml html css bootstrap
      agile scrum kanban jira confluence slack
      machine-learning ai data-science analytics tableau powerbi
      linux unix windows bash shell powershell
      java c# .net spring hibernate maven gradle
    ]
    
    business_skills = %w[
      management leadership team-lead director manager supervisor
      operations strategy planning execution implementation
      project-management stakeholder client customer vendor
      budget financial cost-optimization revenue growth
      process-improvement lean six-sigma automation efficiency
      communication presentation negotiation collaboration
      analytics kpi metrics dashboard reporting compliance
      risk-management quality-assurance testing documentation
      training mentoring coaching development performance
    ]
    
    industry_terms = %w[
      saas b2b b2c e-commerce fintech healthcare edtech
      startup enterprise corporate consulting agency
      remote distributed cross-functional international
      scalable high-availability performance optimization
      security compliance gdpr hipaa sox pci
      innovation digital-transformation cloud-native
    ]
    
    all_keywords = technical_skills + business_skills + industry_terms
    
    # Extract keywords present in job posting
    found_keywords = all_keywords.select { |keyword| 
      job_text.include?(keyword.tr('-', ' ')) || job_text.include?(keyword) 
    }
    
    # Also extract job-specific phrases
    job_phrases = extract_job_phrases(job_text)
    
    (found_keywords + job_phrases).uniq.first(15) # Limit to top 15 most relevant
  end
  
  def extract_job_phrases(job_text)
    # Extract meaningful 2-3 word phrases from job description
    words = job_text.split(/\W+/).reject { |w| w.length < 3 }
    phrases = []
    
    # Extract important business phrases
    (0..words.length-3).each do |i|
      phrase = words[i..i+2].join(' ')
      if phrase.match?(/\b(management|leadership|development|operations|strategy|analysis|implementation|optimization|improvement)\b/)
        phrases << phrase
      end
    end
    
    phrases.uniq.first(8)
  end
  
  def strip_html(html)
    html.gsub(/<[^>]*>/, ' ').gsub(/\s+/, ' ').strip
  end
  
  def generate_suggestions(missing_keywords)
    return [] if missing_keywords.empty?
    
    [
      "Consider adding these missing keywords: #{missing_keywords.first(3).join(', ')}",
      "Include relevant projects or experiences that demonstrate these skills",
      "Add these technologies to your skills section if you have experience with them"
    ]
  end
end