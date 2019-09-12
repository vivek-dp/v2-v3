$(document).ready(function(){
	window.location = 'skp:uptdetail@'+1;
	// $('#name_title option:contains("Mr")').prop("selected",true);
	
	$('#startproject').on('click', function(){
		var json = {};
		var chkids = $keys
		for(var i = 0; i < chkids.length; i++){
			var value = $('#'+chkids[i]).val();
			if (value.length != 0){
				json[chkids[i]] = value
			}else{
				var res = chkids[i].replace(/_/g, " ");
				var cname = res.capitalize()
				toastr.error(cname+" can't be blank!", 'Error');
				$('#'+chkids[i]).focus();
				return false
			}
		}

		var str = JSON.stringify(json);
		$('#loadicon').css("display", "block")
		setTimeout(function() {window.location = 'skp:pro_details@'+ str;}, 500);
	});
});
var $keys = []
String.prototype.capitalize = function() {
  return this.charAt(0).toUpperCase() + this.slice(1);
}

function getPages(val){
	for (var k = 0; k < $keys.length; k++){
		chkval = $('#'+$keys[k]).val().length;
		if (chkval == 0){
			if (val != 1) toastr.info('Please fill the required fields!', 'Info');
			return false;
		}else{
			return true
		}
	}
}

function changePager(){
	$('#loadicon').css('display', 'none');
	$('#add_space').click();
}

function uptAttrValue(inp){
	for(var i = 0; i < inp.length; i++){
		var sval = inp[i].split("|")
		$keys.push(sval[0])
		$('#'+sval[0]).val(sval[1]);
	}
	// if ($('#name_title').val() == null)	$('select option:contains("Mr")').prop('selected',true);
	if ($('#name_title').val() == null)	$('select option[value="Mr"]').attr('selected',true);
}