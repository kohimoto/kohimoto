( function( $ ) {
	$( document ).ready( function() {
		$('a[href$=jpg],a[href$=gif],a[href$=png]').swipebox( {
			hideBarsDelay: 0,
			afterOpen: function () {
				$(document).on('click touchend', function(event) {
					if (!$(event.target).closest('#swipebox-overlay img,#swipebox-overlay .visible-bars').length) {
						$.swipebox.close();
					}
				});
			},
		} );
	} );
} )( jQuery );