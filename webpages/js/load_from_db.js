$(document).ready(function(){
	window.location = 'skp:getspace@' + 1;
});

function passSpace(val){
	document.getElementById('load_space').innerHTML = '<div class="ui form"><div class="field"><div class="ui labeled input"><div class="ui label">Main Category:</div>'+val+'</div></div></div>';
}

function changeSpaceCategory(){
	var val = document.getElementById('main-space').value;
	if (val != 0) {
		window.location = 'skp:get_cat@' + val;
	}else{
		document.getElementById('load_subcat').innerHTML = "";
		// document.getElementById('load_sketchup').innerHTML = "";
	}
}

function passsubCat(input){
	document.getElementById('load_subcat').innerHTML = "";
	document.getElementById('load_carcass').innerHTML = "";
	document.getElementById('load_subcat').innerHTML = '<div class="ui form"><div class="field"><div class="ui labeled input"><div class="ui label">Sub Category:</div>'+input+'</div></div></div>';
}

function changesubSpace(){
	var maival = document.getElementById('main-space').value;
	var subval = document.getElementById('sub-space').value;
	if (subval != 0){
		var value = maival +","+ subval
		window.location = 'skp:load-code@' + value;
	}
}

function passCarCass(inp){
	document.getElementById('load_carcass').innerHTML = '<div class="ui form"><div class="field"><div class="ui labeled input"><div class="ui label">Carcass Code:</div>'+inp+'</div></div></div>';
}

function changeProCode(){
	var main = document.getElementById('main-space').value;
	var cat = document.getElementById('sub-space').value;
	var pro = document.getElementById('carcass-code').value;

	if (pro != 0){
		var input = main +","+ cat +","+ pro
		window.location = 'skp:load-datas@'+ input;
	}
}

function passDataVal(val){
	for (var i = 0; i < val.length; i++){
		var splitval = val[i].split("|")
		if (splitval[0] == "Type"){
			
		}
		alert(splitval[1])
	}
}