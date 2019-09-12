$(document).ready(function(){
	window.location = 'skp:getspace@' + 1;

	$('#btn-carcass').click(function(){
		maincat = $('#main-space').val();
		subcat = $('#sub-space').val();
		joinval = maincat + ',' + subcat
		window.location = 'skp:select-carcass@' + joinval;
	})

	$('#btn-shut').click(function(){
		carcode = $('#carcass_code').val();
		maincat = $('#main-space').val();
		subcat = $('#sub-space').val();
		joinval = maincat + ',' + subcat + ',' + carcode
		window.location = 'skp:show_shutter@'+ joinval;
	})

	$('#btn-int').click(function(){
		carcode = $('#carcass_code').val();
		door = carcode.split("_")[1]
		maincat = $('#main-space').val();
		subcat = $('#sub-space').val();
		page_type = $('#page_type').val();
		joinval = maincat + ',' + subcat + ',' + carcode + ',' + door + ',' + page_type
		window.location = 'skp:show_int_html@'+ joinval;
	})

	$('#rotatebtn').on('click', function(){
		window.location = 'skp:rotate-comp@'+1;
	})

	$('#rotatebt').on('click', function(){
		window.location = 'skp:rotate-comp@'+1;
	})

	$('#auto-place').on('click', function(){
		if ($('#auto-place').is(':checked') == true){
			window.location = 'skp:check-bifold@'+1;
		}else if ($('#auto-place').is(':checked') == false){
			$('#page-info').css('background', '#2e2e2e');
			$('#showauto').css('display', 'none');
			$('#showbtns').css('display', 'block');
			$('#showadd').css('display', 'none');
			$('input[name=autoposition]').each(function(){
				$(this).prop('checked', false);
			});
			if ($('#load_carcass').val() == 1){
				$('#expcomp').removeClass('disabled');
				$('#rotatebtn').removeClass('disabled');
			}
		}
	})

	$('input[name=autoposition]').click(function(){
		window.location = 'skp:placejpg@' + this.value;
	})
});
var $auto_off = 0
function passAutoOff(){
	$auto_off = 1
	$('#auto-place').prop('checked', false);
	$('#page-info').css('background', '#2e2e2e');
	$('#showauto').css('display', 'none');
	$('input[name=autoposition]').each(function(){
		$(this).prop('checked', false);
	});
	$('#add_wall').val(1);
	$('#showbtns').css('display', 'none');
	$('#showadd').css('display', 'block');
	// $('#placecomp').removeClass('disabled');
}

function turnOnAuto(inp){
	$('#auto-place').prop('checked', true);
	$('#page-info').css('background', 'darkslategray');
	$('#showauto').css('display', 'block');
	$('#showbtns').css('display', 'none');
	$('#showadd').css('display', 'block');
	$('input[name=autoposition]').each(function(){
		if ($(this).val() == 'bottom_right') $(this).prop('checked', true);
		window.location = 'skp:placejpg@' + this.value;
	});
	if ($('#load_carcass').val() == 1){
		$('#placecomp').removeClass('disabled');
		$('#rotatebt').removeClass('disabled')
	}else{
		$('#placecomp').addClass('disabled');
		$('#rotatebt').addClass('disabled')
	}
	if (inp == 1){$('#auto_front').css('display', 'block');}else{$('#auto_front').css('display', 'none');}
}

function passJpgImg(path){
	$('#placeimg').html('<img src="'+path+'" width="100%" height="100%">')
}

var $type = 0
var $show_space = 0
var $wall_point = 0
function passSpaceName(val, type){
	// alert('passSpaceName--'+type)
	$show_space = 1
	$('#load_space_list').html('<div class="ui form"><div class="field"><div class="ui labeled input"><div class="ui label">Space Name:</div>'+val+'</div></div></div>')
	if (type != 0){changeList(type)}
}

function passSpace(val, type){
	$type = type
	if ($show_space == 0) $('#load_space_list').html('<div class="ui form"><div class="field"><div class="ui labeled input"><div class="ui label">Space Name:</div>'+val[0]+'</div></div></div>')
		$('#load_maincat').html('<div class="ui form"><div class="field"><div class="ui labeled input"><div class="ui label">Main Category:</div>'+val[1]+'</div></div></div>')
	if (type == 1){changeSpaceCategory()}
}

function changeList(type){
	var sel = $('#space_list').val();
	window.location = 'skp:change-space@' + sel;
	$('#showbtns').css('display', 'none');
	$('#showadd').css('display', 'block');
	$wall_point = 1
}

function changeSpaceList(space){
	window.location = 'skp:change-space@' + space;
}

function changeSpaceCategory(main){
	$('#load_subcat').html('');
	$('#btn-carcass').css('display', 'none');
	$('#btn-shut').css('display', 'none');
	$('#btn-int').css('display', 'none');
	$('#expcomp').addClass("disabled");
	$('#rotatebtn').addClass("disabled");
	$('#placecomp').addClass("disabled");	
	$('#load_comp_detail').css("display", "none");
	$('#load_carcass').val(0);
	if (main != 0) window.location = 'skp:get_cat@' + main;
}

function passsubCat(sub){
	$('#load_subcat').html('');
	$('#load_carcass').html('');
	$('#internal_code').val('')
	$('#load_subcat').html('<div class="ui form"><div class="field"><div class="ui labeled input"><div class="ui label">Sub Category:</div>'+sub+'</div></div></div>')
	if ($type == 1) changesubSpace()
}

function changesubSpace(subcat){
	$('#btn-shut').css('display', 'none');
	$('#btn-int').css('display', 'none');
	$('#load_comp_detail').css("display", "none");
	$('#load_carcass').val(0);
	$('#expcomp').addClass("disabled");
	$('#placecomp').addClass("disabled");	
	$('#rotatebtn').addClass("disabled");
	if ($type == 1){
		window.location = 'skp:update_car@' + 1;
	}else{
		$('#btn-carcass').css('display', 'none');
		if (subcat != 0) $('#loadfitch').css('display', 'block');
		maincat = $('#main-space').val();
		subcat = $('#sub-space').val();
		auto = $('#auto-place').is(':checked')
		vcal = maincat + "," + subcat + "," + auto
		if (subcat != 0) setTimeout(function() {window.location = 'skp:check_car@'+ vcal;}, 500);
	}
}

function showCarBtn(show){
	$('#loadfitch').css('display', 'none');
	if (show == 0){
		toastr.info('Carcasses are not found!', 'Info')
	}else{
		$('#btn-carcass').css('display', 'block');
	}
}

function passIntJs(vals, cat, type){
	var str = ''
	for (var k = 0; k < vals.length; k++){
		var spval = vals[k].split('|')
		var hname = spval[0].capitalize();
		if (hname == 'Left' && type == 1){
			hname = 'Right'
		}else if (hname == 'Right' && type == 1){
			hname = 'Left'
		}
		str += '<input type="hidden" id="int_'+spval[0]+'" value="'+spval[1]+'">'
		str += '<div class="row"><div class="four wide column">'+hname+':</div><div class="twelve wide column" style="color: white;">'+spval[1]+'</div></div>'
	}
	var load_int = '<div class="ui grid">'+str+'</div>'
	$('#internal_code').val(cat)
	$('#internal-cat').html('<h5 class="ui dividing header">Internal Catgory</h5>'+load_int)
	$('#showint').css("margin-top", "10px");

	if (type == 2 && $('#page_type').val() == 1){$('#uptcomp').removeClass('disabled');}else{$('#uptcomp').addClass('disabled');}
	window.location = 'skp:updateglobal@'+1;
	$type = 0
}

String.prototype.capitalize = function() {
  return this.charAt(0).toUpperCase() + this.slice(1);
}

function passCarDetails(details, type){
	$('#load_carcass').val(1);
	if (type == 0){$('#internal-cat').html('');}
	detail = {}
	for(var i = 0; i < details.length; i++){
		split_val = details[i].split('|')
		detail[split_val[0]] = split_val[1]
	}
	$origin = detail['shut_org']
	$('#carcass_code').val(detail['car_code']);

	$('#car-name').html('<div class="four wide column">Carcass Code:</div><div class="twelve wide column"><span style="color: white !important;word-break: break-word;">'+detail['car_name']+'</span></div>');
	
	if (detail['type'].length != 0){
		dtype = '<div class="four wide column">Door Type:</div><div class="twelve wide column"><input type="hidden" id="door_type" value="'+detail['type']+'"><span style="color: white !important;">'+detail['type']+'</span></div>'
	}
	$('#door-type').html(dtype);

	if (detail['shutter_code'].includes('/') == true){
		$('#btn-shut').css('display', 'block');
		$('#shut_code').val('');
		load_shutcode = ''
	}else{
		if (type == 1 && (detail['shutter_code'].includes("AF") == true || detail['shutter_code'].includes("PF") == true)){
			$('#btn-shut').css('display', 'block');	
		}else{$('#btn-shut').css('display', 'none');}
		$('#shut_code').val(detail['shutter_code']);
		if (detail['shutter_code'] != 'No'){
			load_shutcode = '<div class="four wide column">Shutter Code:</div><div class="twelve wide column"><span style="color: white !important;">'+detail['shutter_code']+'</span></div>'
		}else{
			load_shutcode = ''
		}
	}
	$('#shutter-code').html(load_shutcode)

	if (detail['solid'] == "Yes" & detail['glass'] == "No"){
		shut_type = '<div class="four wide column">Shutter Type:</div><input type="hidden" value="solid" id="shttype"><div class="twelve wide column"><span style="color:white !important;">Solid</span></div>'
	}else if (detail['solid'] == "No" & detail['glass'] == "Yes"){
		shut_type = '<div class="four wide column">Shutter Type:</div><input type="hidden" value="glass" id="shttype"><div class="twelve wide column"><span style="color:white !important;">Glass</span></div>'
	}else if (detail['solid'] == "No" & detail['glass'] == "No"){
		shut_type = ''
	}else{
		shut_type = '<div class="four wide column">Shutter Type:</div><input type="hidden" value="solid" id="shttype"><div class="twelve wide column"><span style="color:white !important;">Solid</span></div>'
	}
	$('#shutter-type').html(shut_type)
	
	if (detail['opening'].includes('/') == true){
		$('#shutter_open').val('');
		$('input[name=shopen]').each(function(){
				this.checked = false;
			})
		$('#shutter-open').css('display', 'block');
		$('#shut-open-text').css('display', 'none');
	}else{
		if (detail['opening'] != 'No'){
			$('#shutter_open').val(detail['opening']);
			if (type == 1){
				if (detail['opening'] == 'LHS' || detail['opening'] == 'RHS'){
					upradio = detail['opening'].toLowerCase();
					$('#'+upradio).prop('checked', true);
					$('#shutter-open').css('display', 'block');
				}else{
					$('#shut-open-text').html('<div class="four wide column">Shutter Open:</div><div class="twelve wide column"><span style="color:white !important;">'+detail['opening']+'</span></div>');
				}
			}else{
				$('#shutter-open').css('display', 'none');
				$('#shut-open-text').html('<div class="four wide column">Shutter Open:</div><div class="twelve wide column"><span style="color:white !important;">'+detail['opening']+'</span></div>');
				$('input[name=shopen]').each(function(){this.checked = false;})
			}
		}else{
			$('#shutter-open').css('display', 'none');
			$('input[name=shopen]').each(function(){
				this.checked = false;
			})
			$('#shutter_open').val(detail['opening']);
			$('#shut-open-text').html('')
		}
	}
	
	if ($('#sub-space').val().includes('Sliding') == true){
		$('#btn-int').css('display', 'block');
	}else{
		$('#btn-int').css('display', 'none');
		$('#internal-cat').html('');
	}
	
	if ($('#auto-place').is(':checked') == true){
		if ($('#load_carcass').val() == 1){
			$('#placecomp').removeClass('disabled');
			$('#rotatebt').removeClass('disabled');
		}else{
			$('#placecomp').removeClass('disabled');
			$('#rotatebt').addClass('disabled');
		}
	}else if ($('#auto-place').is(':checked') == false){
		if ($('#load_carcass').val() == 1){
			if ($auto_off == 1){
				$('#placecomp').removeClass('disabled');
				$('#rotatebt').removeClass('disabled');
			}else{
				if ($wall_point != 1){
					$('#expcomp').removeClass('disabled');
					$('#rotatebtn').removeClass('disabled');
				}else{
					$('#placecomp').removeClass('disabled');
					$('#rotatebt').removeClass('disabled');
					$wall_point = 0
				}
			}
		}
	}	

	if ($type == 1){
		if ($('#main-space').val().includes('Sliding') == true || $('#main-space').val().includes('sliding') == true){
			window.location = 'skp:load-internal@'+1;
		}else{
			$('#internal-cat').html('')
			window.location = 'skp:updateglobal@'+1;
			$type = 0
		}
	}

	$('#load_comp_detail').css('display', 'block');
}

function chkopen(open){
	if ($('#page_type').val() == 1) window.location = 'skp:check_open@'+open;
	$('#shutter_open').val(open);
}

function passOpen(val){
	if (val == 1){
		$('#uptcomp').removeClass('disabled');
	}else{
		$('#uptcomp').addClass('disabled');
	}
}

function passShutJs(input){
	$('#shut_code').val(input[0]);
	$('#shutter-code').html('<div class="four wide column">Shutter Code:</div><div class="twelve wide column"><span style="color: white !important;">'+input[0]+'</span></div>')
	if (input[1] == 1 && $('#page_type').val() == 1){$('#uptcomp').removeClass('disabled');}else{$('#uptcomp').addClass('disabled');}
}

function createcomp(val){
	var json = {};

	if ($('#shut_code').val() == "" && $('#shut_code').val() != "No"){
		toastr.error('Please select a shutter to create!', 'Error');
		return false
	}

	if ($('#auto-place').is(':checked') == true){
		var position = $("input[name='autoposition']:checked").val();
		if (position == undefined){
			toastr.error("Auto position can't be blank!", 'Error');
			return false;
		}else{
			json['auto_mode'] = 'true'
			json['auto_position'] = position
		}
	}else if ($('#auto-place').is(':checked') == false){
		json['auto_mode'] = 'false'
		json['auto_position'] = 'false'
	}
	if (val == 0){json['edit'] = 0}else if(val == 1){json['edit'] = 1}
		if ($('#space_list').val() != 0){
		json['space_name'] = $('#space_list').val();
	}else{
		toastr.error("Space Name can't be blank!", "Error")
		return false
	}
	json['main-category'] = $('#main-space').val();
	json['sub-category'] = $('#sub-space').val();
	json['carcass-code'] = $('#carcass_code').val();
	json['door-type'] = $('#door_type').val();
	if ($('#shut_code').val() != "No") json['shutter-code'] = $('#shut_code').val();
	json['shutter-type'] = $('#shttype').val();
	if ($('#shutter_open').val() != ''){
		if ($('#shutter_open').val() != 'No') json['shutter-open'] = $('#shutter_open').val();
	}else{
		toastr.error('Please select shutter opening side!', 'Error')
		return false
	}
	json['shutter-origin'] = $origin

	if ($('#main-space').val().includes("Sliding") == true){
		var intval = $('#internal_code').val();
		if (intval == ""){
			toastr.error('Please select a Internal category!', 'Error');
			return false
		}else{
			if ($('#int_left').val().length != 0) json['left_internal'] = $('#int_right').val();
			if ($('#int_right').val().length != 0) json['right_internal'] = $('#int_left').val();
			if (intval == 3) json['center_internal'] = $('#int_center').val();
			json['internal-category'] = intval;
		}
	}

	var str = JSON.stringify(json);
	$('#loadicon').css('display', 'block');
	if (val == 1){$('#uptcomp').addClass("disabled");}
	setTimeout(function() {window.location = 'skp:send_compval@'+ str;}, 200);
}