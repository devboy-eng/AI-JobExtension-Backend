#!/usr/bin/env ruby

require 'net/http'
require 'json'
require 'uri'

# Test PDF generation endpoint
uri = URI('http://localhost:4003/api/download/pdf')

# Sample HTML content
html_content = '<h1>Test Resume</h1><p>This is a test PDF generation</p>'

# Prepare request
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri)
request['Content-Type'] = 'application/json'
request['Authorization'] = 'Bearer test-token'  # Add actual token if needed
request.body = { htmlContent: html_content }.to_json

# Send request
response = http.request(request)

# Check response
if response.code == '200'
  # Save PDF
  File.open('test_resume.pdf', 'wb') do |file|
    file.write(response.body)
  end
  puts "PDF saved as test_resume.pdf"
  puts "Content-Type: #{response['Content-Type']}"
  puts "File size: #{response.body.length} bytes"
else
  puts "Error: #{response.code}"
  puts response.body
end