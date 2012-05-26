#!/usr/bin/ruby
require 'rubygems'
require 'mechanize'
require 'digest/md5'
require 'net/smtp'

def mail_update(server, port, local,  from, pw,  to, filename, content)

	message = <<MESSAGE
From: GIHEP notifier <#{from}>
MIME-Version: 1.0
Content-type: text/html
Subject:Gihep updated !


#{content}
filename: #{filename}
MESSAGE

	smtp = Net::SMTP.new server, port
	smtp.enable_starttls
	smtp.start(local, from, pw)
	smtp.send_message(message , from, to)
end
 
cfg  = open('cfg.yaml') do |input|
 YAML.load input
end

puts "======== Launching GIHEP Checker ========"
begin
	a = Mechanize.new
	a.get('https://ecolevirtuelle.provincedeliege.be/') do |ev_connnection|

	  #Submit the login form
	  ev_home = ev_connnection.form_with(:id => 'form_connection') do |form_connection|
		puts "- Found connecion form"
		form_connection['p_username']	= cfg['user']
		form_connection['p_password']	= cfg['pw']
	  end.click_button
	  
	  #crappy oracle SSO
	  if ev_home.title.nil?
		puts "- Oracle SSO"
		ev_home = ev_home.form_with(:action => 'https://sso.ecolevirtuelle.provincedeliege.be/pls/orasso/orasso.wwsso_app_admin.ls_login') do |f|
			puts "- Found SSO form"
		end.click_button
	  end
	  
	  a.get('https://ecolevirtuelle.provincedeliege.be/gihepnet/gihepnet.moncursus_gestion.mescours') do |gihep|
		body = gihep.body.gsub(Regexp.new("<div style=\"display:none\">[+0-9 :.]*</div>"), "")
		puts "- GIHEP: " + gihep.title
		
		current_digest = Digest::MD5.hexdigest(body)
		if cfg['last_digest'] != current_digest
			puts "- Update found !"
			
			time_stamp_s = Time.new.strftime('gihep_%m%d_%H%M_%S.html') 
			puts "- Saving in: " + time_stamp_s
			File.open(time_stamp_s, 'w') do |output|    
			  output.puts body
			end  
			
			puts "- Sending mail notification to: "+  cfg['mail-to']
			mail_update(cfg['mail-server'], cfg['mail-port'], cfg['mail-local'],cfg['mail-from'], cfg['mail-pw'], cfg['mail-to'], time_stamp_s, body)
			
			puts "- Mail sent"

			cfg['last_digest'] = current_digest
			File.open('cfg.yaml','w') do |out|
			 YAML.dump cfg, out
			end
		else
			puts "- No updates availables, check later"
		end
	  end

	end
	exit 0
rescue Mechanize::UnauthorizedError => e
	$stderr.puts "* Error: Oracle SSO not successfull, check your password "
	exit 1
end
