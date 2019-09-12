$(document).ready(function(){
	window.location = 'skp:load-material@'+1;

	$('#matcode').on('click', function(){
		$(this).addClass('btnactive');
		$('#colcode').removeClass('btnactive');
		$('#lam_block').css('display', 'block');
		$('#col_block').css('display', 'none');
		$('#material_type').val('material')
		$('#lam-category').val(0);
		$('#lam_types').css('display', 'none');
	});

	$('#colcode').on('click', function(){
		$(this).addClass('btnactive');
		$('#matcode').removeClass('btnactive');
		$('#lam_block').css('display', 'none');
		$('#col_block').css('display', 'block');
		$('#material_type').val('color')
		$('#lam_types').css('display', 'none');
	});

	$('#lamcolor_picker').on('click', function(){
		window.location = 'skp:lam_color@'+1;
	})

	$('#search_val').on('keyup', function(){
		var i = $(this).val().toLowerCase();
		$('.column .lam_name').each(function(){
			var s = $(this).text().toLowerCase();
			$(this).closest('.column')[ s.indexOf(i) !== -1 ? 'show' : 'hide' ]();
		})
	});

	$('#update_color').on('click', function(){
		mt = $('#material_type').val();
		cc = $('#color_code').val();
		str = mt+','+cc
		window.location = 'skp:select-col@'+str;
	})

});

function passLamCat(input){
	$('#lam_block').html('<div class="ui form"><div class="field"><div class="ui labeled input"><div class="ui label">Laminate Category:</div>'+input+'</div></div></div>')
}

function changeLaminate(val){
	$('#lam_types').css('display', 'block');
	window.location = 'skp:get-material@'+val;
}

function passLamImg(val){
	$('#place-img').html(val)
}

function getImgSrc(val){
	mt = $('#material_type').val();
	var imgSrc = $(val).attr("src");
	str = mt+','+imgSrc
	window.location = 'skp:select-lam@'+str;
}