module Decor_Standards

	def self.set_mm_template
		current_template = Sketchup.template
		if File.basename(current_template) != 'Temp02b - Arch.skp'
			puts "Setting millimeter template"
			dir_path 			= File.dirname(current_template)
			Sketchup.template	= File.join(dir_path, 'Temp02b - Arch.skp')
		end
	end
	
	def self.load_login
		dialog = UI::HtmlDialog.new({:dialog_title=>"RioSTD | Login", :preferences_key=>"com.sample.plugin", :scrollable=>false, :resizable=>false, :style=>UI::HtmlDialog::STYLE_DIALOG})
		html_path = File.join(WEBDIALOG_PATH, 'load_login.html')
		dialog.set_file(html_path)
		dialog.set_size(500, 400)
		dialog.center
		dialog.show

		dialog.add_action_callback("loginval"){|a, b|
			spval = b.split(",")
			user_auth = RioDbLib::authenticate_aws_user spval[0], spval[1]
			if user_auth == true
				RioAwsDownload::download_component_list
				set_mm_template
				visible = 1
				$rio_logged_in = true
			elsif user_auth == false
				visible = 0
			end
			jslog = "validateLog("+visible.to_s+")"
			dialog.execute_script(jslog)
		}

		dialog.add_action_callback("checkonline"){|a, b|
			if Sketchup.is_online == true
				online = 1
			elsif Sketchup.is_online == false
				# sample_url='www.example.com'
				# ping_inst = Net::Ping::External.new(sample_url)
				# if ping_inst.ping?
					# online = 1
				# else 
					online = 0
				# end
			end
			jsonline = "passStatus("+[online].to_s+")"
			dialog.execute_script(jsonline)
		}

		dialog.add_action_callback("openapp"){|a, b|
			dialog.close
			self.decor_index()
		}
	end
end