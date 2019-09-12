$(document).ready(function(){
	window.location = 'skp:get_detail@'+1;
	$('#page_content').load("load_welcome.html");
	$('#p0').css("display", "block");

	$(".fbutton").click(function (e) {
		$(this).addClass("active").siblings().removeClass("active");
	});

	$('#clicklogin').on('click', function(){
		var email = $('#email').val();
		var pwd = $('#password').val();
		if ($.trim(pwd).length == 0){
			toastr.error("Password can't be blank!", 'Error');
			$('#password').focus();
			return false;
		}

		arrval = []
		if (email.length != 0 && pwd.length != 0){
			arrval.push(email)
			arrval.push(pwd)
			$('#loadicon').css('display', 'block');
			setTimeout(function() {window.location = 'skp:loginval@'+ arrval;}, 500);	
		}
	});

	$('#email').blur(function(){
		var mail = $('#email').val();
		if ($.trim(mail).length == 0){
			toastr.error("Email can't be blank!", 'Error')
			$('#email').focus();
			return false;
		}
		if (validateEmail(mail)){
			return true;
		}else{
			toastr.error('Invalid email address!', 'Error');
			$('#email').focus();
			$('#email').val('');
			return false;
		}
	});
});

function validateLog(inp){
	if (inp == 1){
		window.location = 'skp:openapp@'+ inp;
	}else if (inp == 0){
		$('#loadicon').css('display', 'none');
		toastr.error('Invalid email or password!', 'Error')
		return false;
	}
}

function hideLoad(val){
	$('#loadicon').css('display', 'none');
}

function hideLoadGen(){
	$('#loadgen').css('display', 'none');
	// window.location = 'skp:minimize_dialog@'+1;
}

function htmlDone(path){
	$('#loadgen').css('display', 'none');
	toastr.success('HTML Generated Successfully!', 'Success')
	setTimeout(function() {window.location = 'skp:openfile@'+ path;}, 500);
}

function validateEmail(sEmail) {
	var filter = /^([\w-\.]+)@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.)|(([\w-]+\.)+))([a-zA-Z]{2,4}|[0-9]{1,3})(\]?)$/;
	if (filter.test(sEmail)) {
		return true;
	}
	else {
		return false;
	}
}

function passPageToJs(page){
	$('#fname').val(page);
}

function pager(pval){
	var cname = $('#client_name').val();
	var pname = $('#project_name').val();
	if (cname != "" && pname != ""){
		$('#page-info').css('background', '#2e2e2e');
		if (pval == 0){
			window.location = 'skp:current-page@'+ 'add_pro_detail';
			$('#current_page').val('add_pro_detail');
			$('#page_content').load("load_welcome.html");
			hideicon(0)
		}else if (pval == 1){
			window.location = 'skp:current-page@'+ 'load_setting';
			$('#current_page').val('load_setting');
			$('#page_content').load("load_setting.html");
			hideicon(1)
		}else if (pval == 2){
			window.location = 'skp:current-page@'+ 'add_comp';
			$('#current_page').val('add_comp');
			$('#page_content').load("load_add_comp.html");
			hideicon(2)
		}else if (pval == 3){
			window.location = 'skp:current-page@'+ 'add_attr';
			$('#current_page').val('add_attr');
			$('#page_content').load("load_add_attr.html");
			hideicon(3)
		}else if (pval == 4){
			window.location = 'skp:current-page@'+ 'exp_work_draw';
			$('#current_page').val('exp_work_draw');
			$('#page_content').load("load_html.html");
			hideicon(4)
		}else if (pval == 5){
			window.location = 'skp:current-page@'+ 'add_space';
			$('#current_page').val('add_space');
			$('#page_content').load("load_space.html");
			hideicon(5)
		}else if (pval == 6){
			window.location = 'skp:current-page@'+ 'rio_utiliity';
			$('#current_page').val('rio_utiliity');
			$('#page_content').load("load_utility.html");
			hideicon(6)
		}
	}else{
		toastr.info('Please fill the mandatory field!', 'Info')
		if (cname == ""){	$('#client_name').focus();}else if (pname == ""){$('#client_name').focus();}
		return false;
	}
}

function hideicon(val){
	if (val == 0){
		$('#p0').css("display", "block");
		$('#p1').css("display", "none");
		$('#p2').css("display", "none");
		$('#p3').css("display", "none");
		$('#p4').css("display", "none");
		$('#p5').css("display", "none");
		$('#p6').css("display", "none");
	}else if (val == 1){
		$('#p0').css("display", "none");
		$('#p1').css("display", "block");
		$('#p2').css("display", "none");
		$('#p3').css("display", "none");
		$('#p4').css("display", "none");
		$('#p5').css("display", "none");
		$('#p6').css("display", "none");
	}else if (val == 2){
		$('#p0').css("display", "none");
		$('#p1').css("display", "none");
		$('#p2').css("display", "block");
		$('#p3').css("display", "none");
		$('#p4').css("display", "none");
		$('#p5').css("display", "none");
		$('#p6').css("display", "none");
	}else if (val == 3){
		$('#p0').css("display", "none");
		$('#p1').css("display", "none");
		$('#p2').css("display", "none");
		$('#p3').css("display", "block");
		$('#p4').css("display", "none");
		$('#p5').css("display", "none");
		$('#p6').css("display", "none");
	}else if (val == 4){
		$('#p0').css("display", "none");
		$('#p1').css("display", "none");
		$('#p2').css("display", "none");
		$('#p3').css("display", "none");
		$('#p4').css("display", "block");
		$('#p5').css("display", "none");
		$('#p6').css("display", "none");
	}else if (val == 5){
		$('#p0').css("display", "none");
		$('#p1').css("display", "none");
		$('#p2').css("display", "none");
		$('#p3').css("display", "none");
		$('#p4').css("display", "none");
		$('#p5').css("display", "block");
		$('#p6').css("display", "none");
	}else if (val == 6){
		$('#p0').css("display", "none");
		$('#p1').css("display", "none");
		$('#p2').css("display", "none");
		$('#p3').css("display", "none");
		$('#p4').css("display", "none");
		$('#p5').css("display", "none");
		$('#p6').css("display", "block");
	}
}