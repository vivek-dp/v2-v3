module Decor_Standards
	def self.get_attr_value()
		@model = Sketchup.active_model
		@selection = @model.selection[0]

		@get_vsides = DP::get_visible_sides @selection

		@show = 0
		if @selection.nil?
			UI.messagebox 'Component not selected!', MB_OK
			@show = 1
		elsif Sketchup.active_model.selection[1] != nil then
			UI.messagebox 'More than one component selected!', MB_OK
			@show = 1
		end
		
		if @show == 0
			@dict_name = 'carcase_spec'
			rawmat = @selection.get_attribute(@dict_name, 'attr_raw_material')
			rawmat = "" if rawmat.nil?
			if @get_vsides[0] == true
				if fsel.get_attribute(:rio_atts, 'filler_right')
					lam_left = ""
					left_laminate = 0
				else
					lam_left = @selection.get_attribute(@dict_name, 'left_lam_value')
					lam_left = "" if lam_left.nil?
					left_laminate = 1
				end
			end

			if @get_vsides[1] == true
				if fsel.get_attribute(:rio_atts, 'filler_left')
					lam_right = ""
					right_laminate = 0
				else
					lam_right = @selection.get_attribute(@dict_name, 'right_lam_value')
					lam_right = "" if lam_right.nil?
					right_laminate = 1
				end
			end

			if @get_vsides[2] == true
				lam_top = @selection.get_attribute(@dict_name, 'top_lam_value')
				lam_top = "" if lam_top.nil?
				top_laminate = 1
			end

			hand = @selection.get_attribute(@dict_name, 'attr_handles_type')
			hand = "" if hand.nil?

			softcl = @selection.get_attribute(@dict_name, 'attr_soft_close')
			softcl = "" if softcl.nil?

			fintyp = @selection.get_attribute(@dict_name, 'attr_finish_type')
			fintyp = "" if fintyp.nil?

			shutfin = @selection.get_attribute(@dict_name, 'front_lam_value')
			shutfin = "" if shutfin.nil?

			intfin = @selection.get_attribute(@dict_name, 'attr_internal_finish')
			intfin = "" if intfin.nil?

			# defcode = @selection.definition.name
			defcode = @selection.definition.get_attribute(@dict_name, 'attr_product_code')
			if !defcode.nil?
				defcode = defcode.gsub("_", " ")
			else
				defcode = @selection.get_attribute(@dict_name, 'attr_product_name')
				defcode = "" if defcode.nil?
			end

			defname = @selection.definition.get_attribute(@dict_name, 'attr_product_name')
			if !defname.nil?
				defname = defname.gsub("_", " ")
			else
				defname = @selection.get_attribute(@dict_name, 'attr_product_name')
				defname = "" if defname.nil?
			end
			
			mainarr = []
			mainarr.push("attr_raw_material|"+rawmat)
		  mainarr.push("attr_handles_type|"+hand)
		  mainarr.push("attr_soft_close|"+softcl)
		  mainarr.push("attr_finish_type|"+fintyp)
			mainarr.push("attr_product_code|"+defcode)
			mainarr.push("attr_product_name|"+defname)
			
			@show_shutter = @selection.get_attribute(:rio_atts, 'shutter-code')
			if @show_shutter.length != 0
				if shutfin.length != 0
					if shutfin.include?('#') == true
						shutter_lam = shutfin
					else
						shutter_lam = RIO_ROOT_PATH+'/materials/'+shutfin
					end
				else
					shutter_lam = ''
				end
			else
				shutter_lam = 'No'
			end
			mainarr.push("front_lam_value|"+shutter_lam)
			if defname.include?("Sliding") || defname.include?("sliding")
				mainarr.push("attr_internal_finish|"+intfin)
			end

		  if left_laminate == 1
		  	if lam_left.length != 0
		  		if lam_left.include?('#') == true
		  			left_lam = lam_left
		  		else
		  			left_lam = RIO_ROOT_PATH+'/materials/'+lam_left
		  		end
		  	else
		  		left_lam = ''
		  	end
		  	mainarr.push("left_lam_value|"+left_lam)
		  end

		  if right_laminate == 1
		  	if lam_right.length != 0
		  		if lam_right.include?('#') == true
		  			right_lam = lam_right
		  		else
		  			right_lam = RIO_ROOT_PATH+'/materials/'+lam_right
		  		end
		  	else
		  		right_lam = ''
		  	end
		  	mainarr.push("right_lam_value|"+right_lam)
		  end

		  if top_laminate == 1
		  	if lam_top.length != 0
		  		if lam_top.include?('#') == true
		  			top_lam = lam_top
		  		else
		  			top_lam = RIO_ROOT_PATH+'/materials/'+lam_top
		  		end
		  	else
		  		top_lam = ''
		  	end
		  	mainarr.push("top_lam_value|"+top_lam)
		  end
			return mainarr
		end
	end

	def self.update_attr(b)
		@dict_name = 'carcase_spec'
		comp = Sketchup.active_model.selection[0]
		inph =	JSON.parse(b)
		inph.each{|k, v|
			if v.is_a?(Array)
				for i in v
					materials = Sketchup.active_model.materials
					material = materials.add('rio_laminate_carcass')
					if i['lam_type'].to_s == 'color'
						material.color = i['image_path']
					else
						material.texture = i['image_path']
					end
					add_laminate_to_comp(comp, material, i['side'])
				end
			else
				if (k.include?("lam_value") == true)
					if v.include?("#") == true
						split_lam = v
					else
						split_lam = v.split("#{RIO_ROOT_PATH}/materials/")[1]
					end
					@selection.set_attribute(@dict_name, k, split_lam) if @selection && !@selection.deleted?
				else
					@selection.set_attribute(@dict_name, k, v) if @selection && !@selection.deleted?
				end
			end
		}
		return 1
	end

	def self.update_multi_laminate(input)
		sel_arr = []
		Sketchup.active_model.selection.each{|seln| sel_arr<<seln}
		sel_arr.each { |comp|
			visible = DP::get_visible_sides comp
			instance = LAM::add_laminate comp, input['front'][0]
			instance = LAM::add_laminate instance, input['left'][0] if visible[0] == true
			instance = LAM::add_laminate instance, input['right'][0] if visible[1] == true
			instance = LAM::add_laminate instance, input['top'][0] if visible[2] == true
		}
	end

	def self.uptdetail()
		keyarr = ['client_name', 'client_id', 'apartment_name', 'flat_number', 'project_name', 'designer_name', 'visualizer_name', 'contract_date', 'target_date', 'name_title']
		newarr = []
		for k in keyarr
			val = Sketchup.active_model.get_attribute(:rio_global, k)
			val = "" if val.nil?
			newarr.push(k+'|'+val)
		end
		return newarr
	end

	def self.get_laminate_cat
		path = RIO_ROOT_PATH + "/materials/"
		dirpath = Dir[path+"*"]
		mainarray = ""
		dirpath.each {|mc|
			lval = mc.split("/").last
			lam = lval.gsub("-", " ")
			mainarray += '<option value="'+lval+'">'+lam+'</option>'
		}
		lastarray = '<select class="ui dropdown" id="lam-category" onchange="changeLaminate(this.value)"><option value="0">Select...</option>'+mainarray+'</select>'
		return lastarray
	end

	def self.get_laminate_img(input)
		path = RIO_ROOT_PATH + "/materials/" + input + "/"
		dirpath = Dir[path+"*"]
		dival = ""
		path_length = (dirpath.length/4)+1
		path_length.times{|index|
			images_arr = dirpath.shift(4)
			lam1 = images_arr[0].split("/").last if !images_arr[0].nil?
			lam1val = lam1.gsub(".jpg", "").gsub(".JPG", "") if !lam1.nil?
			lam2 = images_arr[1].split("/").last if !images_arr[1].nil?
			lam2val = lam2.gsub(".jpg", "").gsub(".JPG", "") if !lam2.nil?
			lam3 = images_arr[2].split("/").last if !images_arr[2].nil?
			lam3val = lam3.gsub(".jpg", "").gsub(".JPG", "") if !lam3.nil?
			lam4 = images_arr[3].split("/").last if !images_arr[3].nil?
			lam4val = lam4.gsub(".jpg", "").gsub(".JPG", "") if !lam4.nil?

			dival += '<div class="ui equal width grid">'
			dival += '<div class="column"><div class="lam_name">'+lam1val+'</div><div class="lam_img"><img src="'+images_arr[0]+'" onclick="getImgSrc(this)"></div></div>' if !images_arr[0].nil?
			dival += '<div class="column"><div class="lam_name">'+lam2val+'</div><div class="lam_img"><img src="'+images_arr[1]+'" onclick="getImgSrc(this)"></div></div>' if !images_arr[1].nil?
			dival += '<div class="column"><div class="lam_name">'+lam3val+'</div><div class="lam_img"><img src="'+images_arr[2]+'" onclick="getImgSrc(this)"></div></div>' if !images_arr[2].nil?
			dival += '<div class="column"><div class="lam_name">'+lam4val+'</div><div class="lam_img"><img src="'+images_arr[3]+'" onclick="getImgSrc(this)"></div></div>' if !images_arr[3].nil?
			dival += '</div>'
		}
		return dival
	end
end