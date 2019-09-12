require 'fileutils'
require_relative 'comp_visible_test.rb'

module Decor_Standards
	def self.export_index(input)
		@views = self.export_html(input['space'])
		return @views
	end

	def self.get_comp_laminate(input)
		lam_json = {}
		 input.each_pair{|name, comp|
		# input.each{|comp|
			comp_dicts = comp.attribute_dictionaries
			if !comp_dicts.nil? && !comp_dicts['carcase_spec'].nil?
				comp_dicts['carcase_spec'].each{|key, val|
					if key.include?('lam_value')
						split = val.split('/')[-1] if !val.nil?
						lam_name = split.gsub(".jpg", "").gsub(".JPG", "") if !val.nil?
						lam_json[lam_name] = RIO_ROOT_PATH + '/materials/' + val if !val.nil?
					end
				}
			end
		}
		return lam_json
	end

	def self.get_comp_attribute input
		@attr_name = 'carcase_spec'
		mainh = {}
		main_arr = []
		input.each_pair{|name, comp|
		# input.each{|comp|
			comp_hash = {}
			comp_hash['id'] = name
			comp_dicts = comp.attribute_dictionaries
			if !comp_dicts.nil? && !comp_dicts[@attr_name].nil?
				comp_dicts[@attr_name].each{|key, val|
					comp_hash[key] = val
				}
			end
			comp_hash['attr_product_name'] = comp.definition.get_attribute(:carcase_spec, 'attr_product_name')
			if comp_hash['attr_product_name'].nil?
				comp_hash['attr_product_name'] = comp.get_attribute(:carcase_spec, 'attr_product_name')
			end
			comp_hash['attr_product_code'] = comp.definition.get_attribute(:carcase_spec, 'attr_product_code')
			if comp_hash['attr_product_code'].nil?
				comp_hash['attr_product_code'] = comp.get_attribute(:carcase_spec, 'attr_product_code')
			end
			comp_hash['comp_width'] 	= DP::get_comp_width comp
			comp_hash['section_plane']	= WorkingDrawing::get_section_list[comp]
			main_arr.push(comp_hash)	
		}
		mainh['attributes'] = main_arr
		return mainh
	end

	def self.export_html(input)
		cname = Sketchup.active_model.get_attribute(:rio_global, 'name_title')+'.&nbsp;'+Sketchup.active_model.get_attribute(:rio_global, 'client_name')

		str = '<!DOCTYPE html>
		<html lang="en">
		<head>
			<meta charset="utf-8">
			<meta name="viewport" content="width=device-width, initial-scale=1">
			<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/semantic-ui/2.4.1/semantic.css" />
		  <script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.3.1/jquery.js"></script>
		  <script src="https://cdnjs.cloudflare.com/ajax/libs/semantic-ui/2.4.1/semantic.js"></script>
		  <link href="https://fonts.googleapis.com/css?family=Poppins" rel="stylesheet">

			<style>
				body {font-size: 10px;}
				.ui.grid > .column:not(.row) {padding-top:5px; padding-bottom:5px;padding-left:5px;}
				.ui.grid + .grid {margin:3px;}
				.elevation {line-height: 30px;text-align: center;font-weight: bold;border-right:1px solid black;color:#DB2828;}
				.details {padding:10px 5px 10px 5px;}
				.brgt {border-right:1px solid black;}
				.details b {color:#DB2828;}
				.page-break {page-break-before:always !important;}
				.column img {border:1px solid black; width:100%; height:100%;}
				.laming {text-align:center;}
				.laming img {height:40px; width:120px;}
				.laming10 {padding-bottom:5px; text-align:center;}
				.laming10 span {padding-left:5px;}
				.laming10 img, .laming10 div {height:30px;width:100%;margin-left:5px;}
				.dividiv {padding-top:0px !important;padding-left:0px !important;padding-right:2px !important;}
				.brht {border-right:1px solid black;}
				.clist {border-bottom: 1px solid black; font-size: 12px; text-decoration: underline; color: #DB2828; padding: 5px;font-family: "Poppins", sans-serif !important;}
				.tc {text-align:center;}
				.tc1 {text-align:center;color:#DB2828;font-weight:bold;}
			</style>
		</head>

		<body>
			<div class="ui container-fluid">'
				input.each {|inp|
					res = scan_room_components inp, true
					if res[1] == false
						UI.messagebox("Please correct the components and rerun export.")
						# $rio_dialog.set_size(650, 780)
						return false
					end
						
					# get_drawing = MRP::get_working_drawing_sides inp
					get_drawing = WD::generate_wd_images inp
					# puts "get_drawing---#{get_drawing}"
					views = get_drawing.keys
					views.delete('top_view')

					params = get_drawing['top_view']
str +=	'<section style="border-style: double;">
						<div class="ui equal width grid" style="margin:0px;border-bottom:1px solid black;">
							<div class="column elevation">Elevation: Top View</div>
							<div class="column details brgt"><b>Client Name:</b><br>'+cname+'</div>
							<div class="column details brgt"><b>Location:</b><br>'+Sketchup.active_model.get_attribute(:rio_global, 'apartment_name')+'</div>
							<div class="column details brgt"><b>Designed By:</b><br>'+Sketchup.active_model.get_attribute(:rio_global, 'designer_name')+'</div>
							<div class="column details brgt"><b>Room Name:</b><br>'+inp+'</div>
							<div class="column details"><b>Date:</b><br>'+Time.now.strftime('%B %Y, %d')+'</div>
						</div>
						<div class="ui grid">
							<div class="sixteen wide column dividiv">
								<div class="row" style="height:450px !important;">
									<div style="width:100%;float:left;height:65em;"><img src="'+params[:top_room_image]+'" width="100%" height="100%"></div>
								</div>
							</div>
						</div>
					</section>
					<div class="page-break"></div>'

					views.each{|view_name|	
						params = get_drawing[view_name]
						get_lam = self.get_comp_laminate(params[:comp_list])
str +=		'<section style="border-style: double;">
							<div class="ui equal width grid" style="margin:0px;border-bottom:1px solid black;">
								<div class="column elevation">Elevation: '+view_name.gsub("_", " ").capitalize+'</div>
								<div class="column details brgt"><b>Client Name:</b><br>'+cname+'</div>
								<div class="column details brgt"><b>Location:</b><br>'+Sketchup.active_model.get_attribute(:rio_global, 'apartment_name')+'</div>
								<div class="column details brgt"><b>Designed By:</b><br>'+Sketchup.active_model.get_attribute(:rio_global, 'designer_name')+'</div>
								<div class="column details brgt"><b>Room Name:</b><br>'+inp+'</div>
								<div class="column details"><b>Date:</b><br>'+Time.now.strftime('%B %Y, %d')+'</div>
							</div>

							<div class="ui grid">'
								if get_lam.length != 0
str +=					'<div class="fourteen wide column dividiv">'
								else
str +=					'<div class="sixteen wide column dividiv">'
								end
str +=					'<div class="row" style="height:450px !important;">
										<div style="width:49.8%;float:left;height:100%;"><img src="'+params[:front_outline_image]+'" width="100%" height="100%"></div>
										<div style="width:49.8%;float:right;height:100%;"><img src="'+params[:front_internal_file_name]+'" width="100%" height="100%"></div>
									</div>

									<div class="row" style="height:220px !important;padding:0px;padding-top:5px;">
										<div style="height:100%;width:59.5%;float:left;"><img src="'+params[:top_internal_file_name]+'"></div>
										<div style="height:100%;width:40%;float:right;padding:0px;"><img src="'+params[:front_rendered_image]+'"></div>
									</div>
								</div>'

								if get_lam.length != 0
str +=					'<div class="two wide column" style="border-left:1px solid black;margin-top:-3px;margin-bottom:-3px;">'
										get_lam.each_pair {|k, v|
											if k.include?('#')
str += 							'<div class="laming10"><span>'+k+'</span><div style="background:'+k+'"></div></div>'
											else
str += 							'<div class="laming10"><span>'+k+'</span><img src="'+v+'"></div>'
											end
										}
str +=					'</div>'
								end
str +=			'</div>
						</section>
						<div class="page-break"></div>

						<section style="border-style:double;">
							<div class="ui equal width grid" style="margin:0px;border-bottom:1px solid black;margin-bottom:2em;">
								<div class="column elevation">Elevation: '+view_name.gsub("_", " ").capitalize+'</div>
								<div class="column details brgt"><b>Client Name:</b><br>'+cname+'</div>
								<div class="column details brgt"><b>Location:</b><br>'+Sketchup.active_model.get_attribute(:rio_global, 'apartment_name')+'</div>
								<div class="column details brgt"><b>Designed By:</b><br>'+Sketchup.active_model.get_attribute(:rio_global, 'designer_name')+'</div>
								<div class="column details brgt"><b>Room Name:</b><br>'+inp+'</div>
								<div class="column details"><b>Date:</b><br>'+Time.now.strftime('%B %Y, %d')+'</div>
							</div>
							<div class="clist">Component Details:</div>
							<div class="ui equal width grid" style="margin:0px;border-bottom:1px solid black;">
								<div class="column brht tc1">Comp ID</div>
								<div class="column brht tc1">Product Code</div>
								<div class="column brht tc1">Product Name</div>
								<div class="column brht tc1">Width</div>
								<div class="column brht tc1">Raw Material</div>
								<div class="column brht tc1">Shutter Laminate</div>
								<div class="column brht tc1">Top Laminate</div>
								<div class="column brht tc1">Left Laminate</div>
								<div class="column brht tc1">Right Laminate</div>
								<div class="column brht tc1">Handles</div>
								<div class="column brht tc1">Soft Close</div>
								<div class="column tc1">Finish Type</div>
							</div>'

							getattr = self.get_comp_attribute(params[:comp_list])
							getattr['attributes'].each{|att|
								pro_code = att['attr_product_code'].nil? ? 'N/A' : att['attr_product_code']
								pro_name = att['attr_product_name'].nil? ? 'N/A' : att['attr_product_name']
								rawmat = att['attr_raw_material'].nil? ? 'N/A' : att['attr_raw_material'].capitalize
								front = att['front_lam_value'].nil? ? 'N/A' : att['front_lam_value']
								if front != "N/A" and !front.nil?
									lamfront1 = front.split('/')[-1]
									lamfront = lamfront1.gsub(".jpg", "").gsub(".JPG", "")
								else
									lamfront = front
								end
								lamtop = att['top_lam_value'].nil? ? 'N/A' : att['top_lam_value'].split('/')[-1]
								lamleft = att['left_lam_value'].nil? ? 'N/A' : att['left_lam_value'].split('/')[-1]
								lamright = att['right_lam_value'].nil? ? 'N/A' : att['right_lam_value'].split('/')[-1]
								handtype = att['attr_handles_type'].nil? ? 'N/A' : att['attr_handles_type'].capitalize
								softclose = att['attr_soft_close'].nil? ? 'N/A' : att['attr_soft_close'].capitalize
								fintype = att['attr_finish_type'].nil? ? 'N/A' : att['attr_finish_type'].capitalize

str +=				'<div class="ui equal width grid" style="margin:0px;border-bottom:1px solid black;">
									<div class="column brht tc">'+att['id'].to_s+'</div>
									<div class="column brht" style="word-break:break-word;padding:5px 0px 5px 2px;">'+pro_code+'</div>
									<div class="column brht" style="word-break:break-word;padding:5px 0px 5px 2px;">'+pro_name+'</div>
									<div class="column brht tc">'+att['comp_width'].to_s+'</div>
									<div class="column brht">'+rawmat+'</div>
									<div class="column brht">'+lamfront+'</div>
									<div class="column brht">'+lamtop.gsub(".jpg", "").gsub(".JPG", "")+'</div>
									<div class="column brht">'+lamleft.gsub(".jpg", "").gsub(".JPG", "")+'</div>
									<div class="column brht">'+lamright.gsub(".jpg", "").gsub(".JPG", "")+'</div>
									<div class="column brht">'+handtype+'</div>
									<div class="column brht tc">'+softclose+'</div>
									<div class="column">'+fintype+'</div>
								</div>'
							}
str += 		'</section>
						<div class="page-break"></div>'
					}
				}
str+='</div>
			</body>
		</html>'

		if Sketchup.active_model.title != ""
			@title = Sketchup.active_model.title
		else
			@title = "Untitled"
		end
		@datetitle = Time.now.strftime('%d-%m_%H-%M')
		FileUtils.mkdir_p RIO_ROOT_PATH+"/reports/WorkingDrawing/"
		@outpath = RIO_ROOT_PATH+"/reports/WorkingDrawing/#{@title}_#{@datetitle}.html"
		File.write(@outpath, str)

		WorkingDrawing::reset_component_count
		return @outpath
	end
end