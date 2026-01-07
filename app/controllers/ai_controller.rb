class AiController < ApplicationController
  skip_before_action :authenticate_user!, only: [:test_ai]
  
  OPENAI_API_KEY = ENV['OPENAI_API_KEY']
  # Force redeploy to pick up new environment variable
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
        customizedContent: add_resume_styling(customized_resume),
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

  def test_ai
    begin
      # Test data
      resume_data = {
        name: "John Doe",
        email: "john@example.com",
        phone: "123-456-7890",
        summary: "Software developer with 3 years of experience in web development",
        skills: ["JavaScript", "React", "Node.js", "Python"]
      }
      
      job_data = {
        title: "Senior Software Engineer",
        company: "Tech Corporation",
        description: "We are seeking a senior software engineer with experience in JavaScript, React, and backend development. Must have 3+ years of experience and strong problem-solving skills."
      }
      
      # Call OpenAI API
      raw_response = call_openai_api(resume_data, job_data)
      
      # Clean the response
      customized_resume = clean_html_response(raw_response)
      
      # Calculate ATS score
      ats_analysis = analyze_ats_compatibility(customized_resume, job_data)
      
      render_success({
        message: "AI is working correctly!",
        customizedContent: add_resume_styling(customized_resume),
        atsScore: ats_analysis[:score],
        keywordsMatched: ats_analysis[:matched],
        keywordsMissing: ats_analysis[:missing],
        openai_api_configured: OPENAI_API_KEY.present?
      })
      
    rescue => e
      render_error("AI test failed: #{e.message}")
    end
  end
  
  private

  def clean_html_response(response)
    # Remove markdown code blocks if present
    cleaned = response.gsub(/```html\s*/, '').gsub(/```\s*$/, '').strip
    
    # Remove any ATS compliance debug content that might have been included
    cleaned = cleaned.gsub(/ATS Compliance Check.*?Keyword Match: \d+%/m, '').strip
    cleaned = cleaned.gsub(/✓ Formatting:.*?✓ Readability:.*?Fail/m, '').strip
    cleaned = cleaned.gsub(/ATS.*?Check.*?\d+%/m, '').strip
    
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
      You are an expert ATS (Applicant Tracking System) optimization specialist and professional resume writer. Create 100% ATS-compliant resumes that pass all modern ATS scanners.

      CRITICAL ATS REQUIREMENTS - MUST FOLLOW:
      1. Use ONLY standard HTML text - NO CSS styling, colors, or complex formatting
      2. Use simple, clean structure with clear headers and plain text
      3. Use standard fonts (Arial, Calibri) and standard font sizes (10-12pt)
      4. Use bullet points with simple • character only
      5. No tables, columns, graphics, or complex layouts
      6. Maximum keyword optimization while keeping natural language
      7. Clear section headings that ATS can parse

      ATS OPTIMIZATION PRIORITIES:
      - Extract and mirror EXACT phrases from job description
      - Include technical skills, soft skills, tools, and methodologies mentioned in JD
      - Use keyword variations (e.g., "project management", "managing projects", "project manager")
      - Incorporate industry-specific terminology and modern buzzwords
      - Ensure keywords appear in multiple sections (summary, skills, experience)
      - Match job title keywords in professional summary and experience descriptions

      PROFESSIONAL SUMMARY REQUIREMENTS:
      - Write 4-5 sentences that directly address the specific job role
      - Start with job-relevant professional title that matches the posting
      - Include years of experience in relevant domain mentioned in JD
      - Highlight 3-4 key achievements that align with job requirements
      - End with career objective that matches company's needs
      - Use EXACT keywords from job posting naturally

      CORE SKILLS OPTIMIZATION:
      - Prioritize skills mentioned in job description first
      - Group related skills logically (Technical, Management, Industry-specific)
      - Include both hard and soft skills from job requirements
      - Add relevant tools, platforms, and methodologies from JD
      - Keep existing user skills but prioritize job-relevant ones
      - Use comma-separated format for easy ATS parsing

      EXPERIENCE ENHANCEMENT:
      - Generate 5-6 achievement-focused bullet points per role
      - Start each bullet with strong action verbs (Led, Implemented, Optimized, Achieved)
      - Include quantifiable results where logical (percentages, improvements, scale)
      - Align responsibilities with target job requirements
      - Use job-specific terminology and keywords naturally
      - Focus on results and impact, not just tasks

      100% ATS-COMPLIANT CLEAN FORMAT (NO STYLING):
      
      Use ONLY this minimal structure for maximum ATS compatibility:

      FULL NAME
      Target Job Title
      Email: email | Phone: phone | Location: location
      LinkedIn: linkedin
      
      PROFESSIONAL SUMMARY
      Write 3-4 sentences that directly mirror the job requirements. Include years of experience, 
      key expertise areas from job posting, and specific value proposition for the target role.
      End with how you'll contribute to the specific company mentioned in job posting.

      CORE SKILLS
      List skills as comma-separated text, prioritizing skills mentioned in job description first

      PROFESSIONAL EXPERIENCE
      
      For each job (chronological order, most recent first):
      Job Title
      Company Name | Location
      Start Date - End Date
      • Generate 4-6 quantified achievements with specific metrics and results
      • Start each bullet with strong action verbs: Led, Managed, Developed, Achieved, Increased, Implemented
      • Include specific numbers, percentages, and business impact where logical
      • Align each achievement with keywords and requirements from the job posting
      • Focus on results and business value delivered, not just job duties
      • Use industry-specific terminology that matches the target job description

      EDUCATION
      [User's exact education - do not modify or add details]

      LANGUAGES
      [User's exact language list - do not add proficiency levels]

      CRITICAL ATS RULES:
      - Use ONLY plain text with basic formatting
      - NO HTML tags, styling, or complex structures
      - NO div containers, inline styles, or CSS
      - Simple bullet points with • character only
      - Clean, linear text structure for ATS parsing
      - Focus entirely on keyword optimization and content quality

      CRITICAL REQUIREMENTS:
      - Use ONLY user's provided education - NO fabrication
      - Use ONLY user's provided languages exactly as given
      - Keep all factual information accurate
      - Return ONLY the resume content - NO explanations, NO debug information
      - NEVER include ATS check results, compliance scores, or debug text in the resume
      - NEVER add phrases like "ATS Compliance Check", "Formatting:", "Keywords:", etc.
      - Focus on ATS-friendly, professional, minimalist design
      - Maximize keyword matching with job description
      - Ensure natural language flow despite keyword optimization
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
      
      IMPORTANT: Return ONLY the clean resume content. Do NOT include any ATS compliance checks, debug information, or explanatory text.
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
    
    # Enhanced ATS keywords categorized by domain with modern technologies
    technical_skills = %w[
      python javascript typescript react angular vue node express nextjs
      sql mysql postgresql mongodb redis elasticsearch dynamodb
      aws azure gcp docker kubernetes terraform ansible jenkins
      git github gitlab bitbucket ci/cd devops microservices serverless
      api rest graphql json xml html css sass bootstrap tailwind
      agile scrum kanban jira confluence slack trello asana
      machine-learning ai ml data-science analytics tableau powerbi looker
      linux unix windows bash shell powershell cmd
      java c# .net spring hibernate maven gradle npm yarn
      flutter react-native swift kotlin ios android mobile
      blockchain web3 cryptocurrency fintech payment-processing
      cybersecurity penetration-testing vulnerability-assessment
      automation testing selenium cypress jest mocha pytest
    ]
    
    business_skills = %w[
      management leadership team-lead director manager supervisor ceo cto
      operations strategy planning execution implementation coordination
      project-management stakeholder client customer vendor partner
      budget financial cost-optimization revenue growth profit margins
      process-improvement lean six-sigma automation efficiency optimization
      communication presentation negotiation collaboration cross-functional
      analytics kpi metrics dashboard reporting compliance audit
      risk-management quality-assurance testing documentation technical-writing
      training mentoring coaching development performance team-building
      sales marketing business-development client-relations customer-success
      product-management roadmap requirements gathering user-experience
      change-management digital-transformation innovation disruption
    ]
    
    industry_terms = %w[
      saas b2b b2c e-commerce fintech healthcare edtech proptech
      startup enterprise corporate consulting agency freelance
      remote distributed hybrid cross-functional international global
      scalable high-availability performance optimization fault-tolerant
      security compliance gdpr hipaa sox pci-dss iso27001
      innovation digital-transformation cloud-native cloud-first
      artificial-intelligence internet-of-things big-data real-time
      user-experience user-interface design-thinking customer-centric
      omnichannel multi-tenant multi-platform cross-platform
      sustainable green-technology renewable-energy esg
    ]
    
    soft_skills = %w[
      problem-solving critical-thinking analytical creative adaptable
      self-motivated proactive detail-oriented results-driven
      time-management multitasking prioritization organization
      interpersonal teamwork collaboration communication presentation
      leadership mentoring coaching conflict-resolution
      customer-focused client-oriented service-minded
      innovative forward-thinking strategic-thinking
    ]
    
    all_keywords = technical_skills + business_skills + industry_terms + soft_skills
    
    # Extract keywords present in job posting
    found_keywords = all_keywords.select { |keyword| 
      job_text.include?(keyword.tr('-', ' ')) || job_text.include?(keyword) 
    }
    
    # Extract job-specific phrases and exact matches from job description
    job_phrases = extract_job_phrases(job_text)
    exact_matches = extract_exact_job_terms(job_text)
    
    # Combine and prioritize most relevant keywords
    all_found = (found_keywords + job_phrases + exact_matches).uniq
    
    # Prioritize by frequency in job posting
    prioritized = all_found.sort_by { |keyword| 
      count = job_text.scan(/#{Regexp.escape(keyword.tr('-', ' ').downcase)}/).length
      -count # Sort in descending order
    }
    
    prioritized.first(20) # Top 20 most relevant keywords
  end
  
  def extract_job_phrases(job_text)
    # Extract meaningful 2-3 word phrases from job description
    words = job_text.split(/\W+/).reject { |w| w.length < 3 }
    phrases = []
    
    # Extract important business phrases
    (0..words.length-3).each do |i|
      phrase = words[i..i+2].join(' ')
      if phrase.match?(/\b(management|leadership|development|operations|strategy|analysis|implementation|optimization|improvement|experience|software|technical|business|product|team|project|data|customer|system|digital|cloud|application|platform|solution|framework|integration|security|performance|quality|process|service|support|innovation|transformation|architecture|infrastructure|engineering|design|analytics|automation|collaboration|communication|planning|execution)\b/)
        phrases << phrase
      end
    end
    
    phrases.uniq.first(12)
  end

  def extract_exact_job_terms(job_text)
    # Extract exact important terms from the job posting
    exact_terms = []
    
    # Look for years of experience patterns
    experience_matches = job_text.scan(/(\d+\+?\s*(?:years?|yrs?)\s*(?:of\s*)?(?:experience|exp)?)/i)
    experience_matches.each { |match| exact_terms << match.first.downcase }
    
    # Extract degree requirements
    degree_matches = job_text.scan(/\b(bachelor'?s?|master'?s?|phd|doctorate|mba|degree|certification|diploma)\b/i)
    degree_matches.each { |match| exact_terms << match.first.downcase }
    
    # Extract specific technologies mentioned with version numbers
    tech_versions = job_text.scan(/\b([a-z]+\s*\d+(?:\.\d+)*|[a-z]+\s*version\s*\d+)\b/i)
    tech_versions.each { |match| exact_terms << match.first.downcase }
    
    # Extract programming languages and frameworks mentioned explicitly
    languages = %w[python javascript typescript java c# php ruby go rust swift kotlin scala r matlab]
    frameworks = %w[react angular vue django flask spring laravel symfony rails express fastapi tensorflow pytorch]
    
    (languages + frameworks).each do |tech|
      if job_text.include?(tech)
        exact_terms << tech
      end
    end
    
    exact_terms.uniq.first(10)
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

  def add_resume_styling(resume_content)
    # Return clean content without any styling for maximum ATS compatibility
    resume_content
  end

  def get_resume_css_styles
    # Read the CSS file and return its contents
    css_file_path = Rails.root.join('app', 'assets', 'stylesheets', 'resume_templates.css')
    
    if File.exist?(css_file_path)
      File.read(css_file_path)
    else
      # Fallback inline styles if file not found
      <<~CSS
        .resume-container {
          font-family: Arial, sans-serif;
          font-size: 11pt;
          line-height: 1.4;
          color: #333;
          max-width: 8.5in;
          margin: 0 auto;
          padding: 0.5in;
          background: white;
        }
        .name {
          font-size: 24pt;
          font-weight: bold;
          color: #2c3e50;
          text-transform: uppercase;
          margin-bottom: 5px;
        }
        .section-title {
          font-size: 14pt;
          font-weight: bold;
          color: #2c3e50;
          text-transform: uppercase;
          border-bottom: 1px solid #34495e;
          margin-bottom: 10px;
        }
        .job-title {
          font-size: 12pt;
          font-weight: bold;
          color: #2c3e50;
        }
        .company {
          font-weight: 600;
          color: #34495e;
        }
        .achievements li {
          margin-bottom: 4px;
        }
      CSS
    end
  end
end