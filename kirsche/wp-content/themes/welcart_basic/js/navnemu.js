$(function () {
//	'use strict';

	$('.js-fullheight').css('height', $(window).height());
	$(window).resize(function(){
		$('.js-fullheight').css('height', $(window).height());
	});

	$('.nav-toggle').on('click', function(event) {

		event.preventDefault();
		var $this = $(this);
		if( $('body').hasClass('menu-show') ) {
				$('body').removeClass('menu-show');
				$('#nav > .nav-toggle').removeClass('show');
		} else {
				$('body').addClass('menu-show');
				setTimeout(function(){
				$('#nav > .nav-toggle').addClass('show');
				}, 900);
			}
		});

});
