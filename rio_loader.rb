require "C:/RioSTD/external_libs/sqlite3/2.2/sqlite3_native.so"

RIO_ROOT_PATH = File.join(File.dirname(__FILE__))
SUPPORT_PATH = File.join(File.dirname(__FILE__))
CONTROL_PATH = File.join(SUPPORT_PATH, 'controller')
WEBDIALOG_PATH   = File.join(SUPPORT_PATH, 'webpages/html')
RIO_TEMP_PATH = File.join(SUPPORT_PATH, 'temp/')

RIO_IMAGE_FILE_TYPE = ".jpg"
SKP_FILE_TYPE = ".skp"

SKETCHUP_CONSOLE.show
#require 'rubygems'

V2_V3_CONVERSION_FLAG=true

puts "Checking Gem files"

begin
	require "mysql"
rescue LoadError
	puts "mysql not found"
	Gem::install 'ruby-mysql'
end

begin
	require "sqlite3"
rescue LoadError
	puts "sqlite not found"
	begin
		Gem::install "sqlite3"
	rescue
		puts "install error"
	end
end

begin
	require "aws-sdk"
rescue LoadError
	Gem::install "aws-sdk"
end

def rioload_ruby path
    ruby_file_name = path + '.rb'
    file_name = File.join(RIO_ROOT_PATH, ruby_file_name)
    puts file_name
    if File.exists?(file_name)
        return Sketchup.load file_name
    end
end


def z
	comp=Sketchup.active_model.selection[0]
	if comp
		point = comp.transformation.origin
		vector = Geom::Vector3d.new(0,0,1)
		
		
		angle = 90.degrees
		transformation = Geom::Transformation.rotation(point, vector, angle)
		comp.transform!(transformation)
	else
		puts "No component selected"
	end
end


Sketchup.active_model.definitions['Chris'].instances.each{|x| x.visible=false} if Sketchup.active_model.definitions['Chris']

module Decor_Standards
	# json = File.read(RIO_ROOT_PATH+'/'+'schema.json')
	# obj = JSON.parse(json)
	# obj['settings'].each_pair{|key, val|
		# Sketchup.active_model.set_attribute(:rio_settings, key, val)
	# }

	puts "Loading files"
	
	path 			= File.dirname(__FILE__)
	cont_path 		= File.join(path, 'controller')
	ext_lib_path 	= File.join(path, 'external_libs')
	
	#External libraries
	Sketchup::require File.join(ext_lib_path, 'color_picker.rb') #Library for choosing the color.
	Sketchup::require File.join(ext_lib_path, 'ping.rb') #Library for login page check

	#Rio libraries
	Sketchup::require File.join(cont_path, 'login_control.rb')
	Sketchup::require File.join(cont_path, 'load_toolbar.rb')
	Sketchup::require File.join(cont_path, 'work_drawing.rb')
	Sketchup::require File.join(cont_path, 'working_drawing.rb')
	Sketchup::require File.join(cont_path, 'aws_database.rb')
	Sketchup::require File.join(cont_path, 'aws_downloader.rb')
	Sketchup::require File.join(cont_path, 'dp_core.rb')
	Sketchup::require File.join(cont_path, 'add_attribute.rb')
	Sketchup::require File.join(cont_path, 'create_comp.rb')
	Sketchup::require File.join(cont_path, 'home_file.rb')
	Sketchup::require File.join(cont_path, 'export_html.rb')
	Sketchup::require File.join(cont_path, 'dp_core.rb')
	Sketchup::require File.join(cont_path, 'multi_room.rb')
	Sketchup::require File.join(cont_path, 'room_tool.rb')
	Sketchup::require File.join(cont_path, 'wall_tool.rb')
	Sketchup::require File.join(cont_path, 'new_laminate.rb')
	Sketchup::require File.join(cont_path, 'multi_room_preprocess.rb')
	Sketchup::require File.join(cont_path, 'multi_room_door.rb')
	Sketchup::require File.join(cont_path, 'schema.rb')
	Sketchup::require File.join(cont_path, 'add_internal_dimension.rb')
	Sketchup::require File.join(cont_path, 'component_outline.rb')
	Sketchup::require File.join(cont_path, 'comp_lib.rb')
	Sketchup::require File.join(cont_path, 'rio_logger.rb')
	
	DP::create_layers
	
	
	# class MyEntitiesObserver < Sketchup::EntitiesObserver
	# 	def onElementAdded(entities, entity)
	# 		if entity.is_a?(Sketchup::ComponentInstance) && !entity.deleted?
	# 			dict = nil
	# 			if entity.definition.attribute_dictionaries
	# 				dict = entity.definition.attribute_dictionaries['rio_atts']
	# 			elsif entity.attribute_dictionaries
	# 				dict = entity.attribute_dictionaries['rio_atts']
	# 			end
	# 			#puts "dict : #{dict}"
				
	# 			if dict
	# 				entity.layer = 'DP_Comp_layer'
	# 				entity.set_attribute :rio_atts, 'rio_comp', true
	# 				space_name = entity.definition.get_attribute(:rio_atts, 'space_name', space_name)
	# 				entity.set_attribute :rio_atts, 'space_name', space_name
	# 				puts "Rio Component Added"

	# 					dict_name='carcase_spec'
	# 					defn   = entity.definition.get_attribute(dict_name, 'attr_product_code')
	# 					entity.set_attribute(dict_name, 'attr_product_code', defn) 

	# 					dictionaries = ['carcass_spec', 'rio_atts']
	# 					entity.definition.attribute_dictionaries.each{|dict|
	# 						next if !dictionaries.include?(dict.name)
	# 						dict.each_pair {|key,val| 
	# 							entity.set_attribute dict.name, key, val 
	# 						}
	# 					}

					
	# 				#DP::update_all_room_components
	# 				# DP::update_entity_bounds entity
	# 			end
	# 		end
	# 	end
	# end

	class MyEntityObserver < Sketchup::EntityObserver
		def onChangeEntity(entity)
			puts "onChangeEntity: #{entity}"
		end
	end

	class MySelectionObserver < Sketchup::SelectionObserver
		def onSelectionBulkChange(selection)
		  # puts "onSelectionBulkChange: #{selection}"
		  js_page = "document.getElementById('add_attr').click();"
			$rio_dialog.execute_script(js_page)
		end
	end
	
	 
	#Attach the observer
	puts "Attaching observer"
	#observer = MyEntitiesObserver.new
	#Sketchup.active_model.entities.add_observer(observer)


	chris_defn = Sketchup.active_model.definitions['Chris']
	if chris_defn
		Sketchup.active_model.place_component chris_defn
		Sketchup.active_model.select_tool(nil)
	end

	['Wall', 'Door', 'Window'].each {|layer_name|
		layer = Sketchup.active_model.layers[layer_name]
		layer.name=layer_name if layer
	}
end

puts "Adding layers"
['DP_Comp_layer', 'DP_Cust_Comp_layer', 'Wall', 'Door', 'Window'].each {|layer_name|
	layer = Sketchup.active_model.layers[layer_name]
	Sketchup.active_model.layers.add(layer_name) unless layer
	layer.name=layer_name if layer
}

puts "Rio Loaded..................."