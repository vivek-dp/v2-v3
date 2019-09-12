#-------------------------------------------------------------------------------------
#
#Aws file list download and file download here
#
#---------------------------------------------------
require 'aws-sdk'

module RioAwsDownload
	KEY_FILE_LOC ||= ENV['TEMP']+'\.aws_cache'
	AWS_ASSETS_REGION ||= 'ap-south-1'
	$filename_std = 'Rio_carcass_components_1.4.csv'
	$filename_int = 'Rio_sliding_door_1.0.csv'
	
	def self.aws_credentials
		key_contents 	= File.read(KEY_FILE_LOC)
		keys 			= key_contents.split(',')
		Aws.config[:region] = AWS_ASSETS_REGION
		
		aws_credentials = {	'access_key_id' 	=> DP::simple_decrypt(keys[0]), 
							'secret_access_key' => DP::simple_decrypt(keys[1])}
		@s3_client  = Aws::S3::Client.new(
							access_key_id: aws_credentials['access_key_id'],
							secret_access_key: aws_credentials['secret_access_key']
						)
		
		aws_credentials
	end
	
	def self.get_s3_client
		aws_credentials if @s3_client.nil?
		return @s3_client
	end
	
	#-------------------------------------------------------------------
	#Inputs :
	#------------
	#	folder_prefix 	: prefix of the folder_files
	#	bucket_name 	: defaults to test bucket
	#Return :
	#------------
	# 	folders and files in the current folder
	# For bucket folder : Use '' for bucket folder
	# Use folder prefix as 'folder_name/' for other folders
	#-------------------------------------------------------------------
	def self.get_folder_files folder_prefix, bucket_name='test.rio.assets' 
		s3_client	= get_s3_client
		bucket_objs = @s3_client.list_objects_v2(
						{	bucket: bucket_name, 
							prefix: folder_prefix}
						)
		folder_files 	=[];
		current_files	= []
		if bucket_objs.contents.length > 1
			bucket_objs.contents.each{|x| folder_files << x.key}
			folder_files.each { |name|
				name.slice!(folder_prefix)
				fname = name.split('/')[0]
				current_files << fname unless current_files.include?(fname)
			}
			puts "current_files  : #{current_files}"
			unless current_files.empty?
				current_files.reject!{ |e| e.to_s.empty? } #removes nil and empty strings
				current_files.compact! 
			end
		end
		puts current_files
		
		#If skps are found
		skp_files={:skps=>[], :jpgs=>[], :prefix=>folder_prefix}
		current_files.each { |fname|
			skp_files[:skps] << fname if fname.end_with?('.skp')
			skp_files[:jpgs] << fname if fname.end_with?('.jpg')
		}
		puts "skps : #{skp_files}"
		
		if skp_files[:skps].empty?
			return current_files
		else
			return skp_files
		end
	end 
	
	#Only for skp....write separate method for other files
	def self.download_skp file_path, bucket_name='test.rio.assets' 
		s3_client	= get_s3_client
		temp_dir 	= ENV['TEMP']
		file_name 	= File.basename(file_path)
		target_path = temp_dir + "\\" + file_name
		begin
			resp 	= s3_client.get_object(bucket: bucket_name, key: file_path, response_target: target_path)
			return target_path
		rescue Aws::S3::Errors::NoSuchKey
			puts "File Does not exist"
			return nil
		end
		return nil
	end
	
	def self.download_jpg file_path, bucket_name='test.rio.assets' 
		s3_client	= get_s3_client
		temp_dir	= ENV['TEMP']
		file_name 	= File.basename(file_path)
		target_path = temp_dir + "\\" + file_name
		begin
			resp 	= s3_client.get_object(bucket: bucket_name, key: file_path, response_target: target_path)
			return target_path
		rescue Aws::S3::Errors::NoSuchKey
			return nil
		end
		return nil
	end

	def self.download_file bucket_name, file_path, target_path
		s3_client	= get_s3_client
		begin
			resp 	= s3_client.get_object(bucket: bucket_name, key: file_path, response_target: target_path)
			return target_path
		rescue Aws::S3::Errors::NoSuchKey
			return nil
		end
		return nil
	end
	
	def self.download_component_list
		s3_client	= get_s3_client
		target_path	= File.join(RIO_ROOT_PATH+'/cache/'+$filename_std)
		bucket_name	= 'rio-bucket-1'

		begin
			resp 	= s3_client.get_object(bucket: bucket_name, key: $filename_std, response_target: target_path)
			self.create_carcass_database
			return target_path
		rescue Aws::S3::Errors::NoSuchKey
			return nil
		end
		return nil
	end

	def self.create_carcass_database
		dbname = 'rio_std'
		@table = 'rio_standards'
		@db = SQLite3::Database.new(dbname)

		db_file_path = File.join(RIO_ROOT_PATH+"/"+"cache/"+$filename_std)
		if !File.exists?(db_file_path)
						
		end
		csv_arr     = CSV.read(db_file_path)
		fields      = csv_arr[0]
		
		#Delete table if already exists
		sql_query   = 'DROP TABLE IF EXISTS '+@table+';'
		@db.execute(sql_query);
		
		#Create fresh table
		sql_query   = 'CREATE TABLE '+@table+' ('
		fields.each { |field|
			sql_query += field + ' TEXT,'
		}
		sql_query.chomp!(',');
		sql_query += ');'
		@db.execute(sql_query);
		
		#Add rows to database
		multi_query = 'INSERT INTO '+@table+' ('+fields.join(',')+') VALUES '
		(1..csv_arr.length-1).each { |index|
			row_values = csv_arr[index].to_s
			row_values.slice!(0);   row_values.chomp!(']')
			if fields.length == csv_arr[index].length
				multi_query   += '('+row_values+'),'
			else
				puts "Number of fields and columns not equal : #{row_values}"
			end
		}
		multi_query = multi_query.chomp(',') + ';'
		@db.execute(multi_query);
		puts "Components are loaded."
		self.download_sliding_list
	end

	def self.download_sliding_list
		s3_client	= get_s3_client
		target_path	= File.join(RIO_ROOT_PATH+'/cache/'+$filename_int)
		bucket_name	= 'rio-bucket-1'
		begin
			resp 	= s3_client.get_object(bucket: bucket_name, key: $filename_int, response_target: target_path)
			self.create_sliding_database
			return target_path
		rescue Aws::S3::Errors::NoSuchKey
			puts "File Does not exist"
			return nil
		end
		return nil
	end

	def self.create_sliding_database
	  dbname = 'rio_std'
		@table = 'rio_slidings'
		@dbt = SQLite3::Database.new( dbname )
		db_file_path= File.join(RIO_ROOT_PATH+"/"+"cache/"+$filename_int)
		
		csv_arr = CSV.read(db_file_path)
		fields = csv_arr[0]
		
		#drop table
		sql_query   = 'DROP TABLE IF EXISTS '+@table+';'
		@dbt.execute(sql_query);

		#Create new table
		sql_query = 'CREATE TABLE '+@table+' ('
		fields.each { |field|
			sql_query += field + ' TEXT,'
		}
		sql_query.chomp!(',');
		sql_query += ');'
		@dbt.execute(sql_query);

		multival = 'INSERT INTO '+@table+' ('+fields.join(',')+') VALUES '
		(1..csv_arr.length-1).each{|ind|
			rowval = csv_arr[ind].to_s
			rowval.slice!(0); rowval.chomp!(']')
			if fields.length == csv_arr[ind].length
				multival += '('+ rowval +'),'
			end
		}
		multival = multival.chomp(',') + ';'
		@dbt.execute(multival);
		puts "Internals are loaded."
	end

end
