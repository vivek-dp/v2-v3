module DS
	def self.setting_page
		Sketchup.active_model.attribute_dictionaries['rio_settings'].each{|key, val|}
		obj = JSON.parse(json)
		return obj['settings']
	end

	def self.update_setting input
		hash = {"settings": input}
		File.open(RIO_ROOT_PATH+'/'+'schema.json',"w") do |f|
			f.write(hash.to_json)
		end
	end
end