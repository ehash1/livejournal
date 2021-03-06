// ---------------------------------------------------------------------------
//   S2 DHTML editor
//
//   s2gui.js - S2 GUI routines
// ---------------------------------------------------------------------------

var s2output = function() {
	var el;

	function parseLineNumbers(text) {
		var match,
			regex = /line\s+(\d+),\s+column\s+(\d+)/g,
			subs = [];
		while (match = regex.exec(text)) {
			subs.push({ key: match[0], link: '<a href="javascript:s2jumpTo(' +
						match[1] + ',' + match[2] + ')">' + match[0] + '</a>'});
		}
		subs.forEach(function(el) {
			text = text.replace(el.key, el.link);
		});

		return text;
	}

	return {
		init: function() {
			el = jQuery('#out');

			if (!s2settings.turboEnabled()) {
				return;
			}

			var text = el.html();
			if (text.length > 0) {
				text = parseLineNumbers(text);
				el.html(text);
			}
		},

		add: function(text, overwrite) {
			overwrite = overwrite || false;
			text = parseLineNumbers(text);

			if (overwrite) {
				el.html(text);
			} else {
				el.append(text);
			}
		}
	}
}();

var s2status;

function s2printStatus(str)
{
	s2status = str;
	
	xGetElementById('status').innerHTML = str;
	xGetElementById('statusbar').style.backgroundColor = '#ffffff';
}

function s2printStatusColor(str, color)
{
	s2status = str;
	
	xGetElementById('status').innerHTML = str;
	xGetElementById('statusbar').style.backgroundColor = color;
}

// Clears the status line if it's equal to the given string.
function s2clearStatus(str)
{
	if (s2status == str)
		s2printStatus("");
}

function s2getCodeArea()
{
	return xGetElementById('main');
}

function s2getCode()
{
	return s2isAceActive() ? aceEditor.getSession().getValue() : xGetElementById('main').value;
}

function s2isAceActive() {
	return !jQuery('#main').is(':visible');
}

function s2setCode(to)
{
	xGetElementById('main').innerHTML = to;
}

function s2getNav()
{
	return xGetElementById('nav');
}

function s2updateNav()
{
	var i = 0;
	var html = '';
	
	while (s2index["" + i] != null) {
		var symbols = s2index["" + i];
		for (var j = 0; j < symbols.length; j++) {
			var sym = symbols[j];
			html += '<div class="';
			switch (sym.type) {
				case 0:		html += 'navfunction';		break;
				case 1:		html += 'navmethod';		break;
				case 2:		html += 'navpropgroup';		break;
			}
			html += '"><a href="javascript:s2jumpToPos(' + sym.loc;
			html += ',' + sym.line + ')">' + sym.name + "</a></div>\n";
		}
		
		i++;
	}
	
	s2getNav().innerHTML = html;
}

function s2keyPressed(e)
{
	s2dirty = 1;
	
	var area = s2getCodeArea();
	
	if (e) {
		if (e.keyCode == 9) {
			if (!s2acceptCompletion()) {
				nxinsertText(area, "\t");
				area.focus();
			}
			Event.preventDefault(e);
			return false;
		} else
			s2sense(e.charCode);
	}
	
	return true;
}

function s2IETabKeyPressedHandler(e)
{
	var area = s2getCodeArea();

	if ((nxIE || ~navigator.userAgent.toLowerCase().indexOf('safari')) && e) {
		if (e.keyCode == 9) {
			if (!s2acceptCompletion()) {
				nxinsertText(area, "\t");
				area.focus();
			}
			Event.preventDefault(e);
			return false;
		}
	}
}

function s2jumpTo(line, column) {
	if (s2isAceActive()) {
		aceEditor.gotoLine(line, column - 1);
		return;
	}

	var main = s2getCodeArea(),
		text = main.value,
		pos = text.split('\n').slice(0, line - 1).join('\n').length + column;

	if (jQuery.browser.msie) { //ie doesn't count linebreaks when positioning cursor
		pos -= line - 1; 
	}

	s2jumpToPos(pos, line);
}

function s2jumpToPos(pos, line)
{
	if (s2isAceActive()) {
		aceEditor.gotoLine(line, 0);
		return;
	}
	var main = s2getCodeArea();

	nxpositionCursor(main, pos);
	nxscrollObject(main, line, s2lineCount);
}

// ---------------------------------------------------------------------------
//   Reference pane interactivity
// ---------------------------------------------------------------------------

function s2toggleRefVis(theID)
{
	var obj = xGetElementById(theID);
	
	if (obj.className && obj.className == 'refinvisible')
		obj.className = 'refvisible';
	else
		obj.className = 'refinvisible';
}

function s2toggleTreeNode(n)
{
	s2toggleRefVis("treenode" + n);
	
	var obj = xGetElementById("treenodeheader" + n);
	if (obj.className == 'treenodeopen')
		obj.className = 'treenode';
	else
		obj.className = 'treenodeopen';
}

function s2switchRefTab(n)
{
	if (n == -1) {
		xGetElementById('navtabs').className = 'refvisible';
		xGetElementById('nav').className = 'refvisible';
	} else {
		xGetElementById('navtabs').className = 'refinvisible';
		xGetElementById('nav').className = 'refinvisible';
	}

	if (n == 0) {
		xGetElementById('classtabs').className = 'refvisible';
		xGetElementById('classref').className = 'refvisible';
	} else {
		xGetElementById('classtabs').className = 'refinvisible';
		xGetElementById('classref').className = 'refinvisible';
	}
	
	if (n == 1) {
		xGetElementById('functabs').className = 'refvisible';
		xGetElementById('funcref').className = 'refvisible';
	} else {
		xGetElementById('functabs').className = 'refinvisible';
		xGetElementById('funcref').className = 'refinvisible';
	}
	
	if (n == 2) {
		xGetElementById('proptabs').className = 'refvisible';
		xGetElementById('propref').className = 'refvisible';
	} else {
		xGetElementById('proptabs').className = 'refinvisible';
		xGetElementById('propref').className = 'refinvisible';
	}
}

// ---------------------------------------------------------------------------
//   Reference pane generation
// ---------------------------------------------------------------------------

function s2buildClasses()
{
	if (s2classlib == null)
		return;
		
	var html = "";
	for (var i = 0; i < s2classlib.length; i++) {
		var classURL = s2docBaseURL + '/core1.class.' + s2classlib[i].name +
			'.html';
	
		html += '<div id="treenodeheader' + i + '" class="treenode" ' +
			'onClick="s2toggleTreeNode(' + i + ')">' + '<a href="' +
			classURL + '" target="_blank">' + s2classlib[i].name +
			'</a></div>\n';
		html += '<div id="treenode' + i + '" class="refinvisible">\n';
		
		for (var j = 0; j < s2classlib[i].members.length; j++)
			html += '<div class="treevar"><a href="' + classURL +
				'#core1.member.' + s2classlib[i].name + '.' +
				s2classlib[i].members[j].name + '" target="_blank">' +
				s2classlib[i].members[j].type +
				' ' + s2classlib[i].members[j].name + '</a></div>\n';
				
		for (var j = 0; j < s2classlib[i].methods.length; j++)
			html += '<div class="treemethod"><a href="' + classURL + '#core1.meth.' + s2classlib[i].name + '.' +
				escape(s2classlib[i].methods[j].name) + '" target="_blank">' +
				s2classlib[i].methods[j].name +
				(s2classlib[i].methods[j].type == 'void' ? '' : ' : ' +
				s2classlib[i].methods[j].type) + '</a></div>\n';
				
		html += '</div>\n';
	}
	
	xGetElementById('classref').innerHTML = html;
}

function s2buildFunctions()
{
	if (s2funclib == null)
		return;
		
	var html = "";
	for (var i = 0; i < s2funclib.length; i++) {
		var funcURL = s2docBaseURL + '/siteapi.core1.html#core1.func.' +
			s2funclib[i].name;
	
		html += '<div class="treefunction"><a href="' + funcURL +
			'" target="_blank">' + s2funclib[i].name.replace(/,/, ', ') +
				(s2funclib[i].type == 'void' ? '' : ' : ' + s2funclib[i].type)
				+ '</a></div>\n';
	}
	
	xGetElementById('funcref').innerHTML = html;
}

function s2buildProperties()
{
	if (s2proplib == null)
		return;
		
	var html = "";
	for (var i = 0; i < s2proplib.length; i++) {
		var propURL = s2docBaseURL + '/siteapi.core1.html#core1.prop.' +
			s2proplib[i].name;
	
		html += '<div class="treeproperty"><a href="' + propURL +
			'" target="_blank">' + s2proplib[i].type + ' $*' +
			s2proplib[i].name.replace(/,/, ', ') + '</a></div>\n';
	}
	
	xGetElementById('propref').innerHTML = html;
}

function s2buildReference()
{
	s2buildClasses();
	s2buildFunctions();
	s2buildProperties();

	if (!s2settings.turboEnabled() && window.name)
	{
		setTimeout(function() {
			var pos = window.name.split(':'), textarea = s2getCodeArea();
			textarea.scrollTop = +pos[0] || 0;
			nxpositionCursor(textarea, pos[1] || 0)
			window.name = '';
		}, 1)
	}
}

// ---------------------------------------------------------------------------
//   Main/build and main/reference pane dragging
// ---------------------------------------------------------------------------

var s2isDraggingOutput = 0;
var s2outputDragMouseOrigin;
var s2outputDragBoxOrigin = 0;
var s2outputBaseValue = 0;
var s2isDraggingRef = 0;
var s2refDragMouseOrigin;
var s2refDragBoxOrigin = 0;
var s2refBaseValue = 0;

function selectEnabled(which)
{
	var main   = document.getElementById("main");
	var output = document.getElementById("out");
	var callback = function () { event.cancelBubble = true; return which; };
	main.onselectstart = output.onselectstart = callback;
}

function s2resizeOutput(force)
{
	if (s2outputBaseValue == 0)
		return false;
	
	var output = xGetElementById('out');
	var maindiv = xGetElementById('maindiv');
	var maindiv = xGetElementById('maindiv');
	var main    = xGetElementById('main');
	var divider = xGetElementById('outputdivider');
	
	var oHeight = s2outputBaseValue;
	var mBottom = 43 + 18 + oHeight;
	
	var height = nxIE ? xGetElementById('statusbar').offsetTop + 16 : window.innerHeight;
		
	if (nxIE)
		oHeight -= 6;
	
	if (!force && (oHeight < 32 || mBottom > height - (26 + 32)))
		return true;	// sanity check
	
	output.style.height = oHeight + 'px';
	
	if (nxIE)
		divider.style.bottom = (55 + oHeight) + 'px';
	else {
		maindiv.style.bottom = mBottom + 'px';
		divider.style.bottom = (50 + oHeight) + 'px';

		// Opera 8 has a strange quirk where it doesn't recalculate the computed
		// height of a box until the width changes, so we just play about with
		// the text field here to force this recalculation.
		var oldwidth = main.style.width;
		main.style.width = "50px";
		main.style.width = oldwidth;
	}

	if (window.aceEditor) {
		aceEditor.resize();
	}
}

function s2resizeReference(force)
{
	if (s2refBaseValue == 0)
		return false;

	var rWidth = s2refBaseValue;
	var mLeft = rWidth + 204 - 174;
	
	if (!force && (rWidth < 150 || mLeft > xGetElementById('statusbar').clientWidth -
		12 - 150))
		return true;	// sanity check
	
	var ref = xGetElementById('ref');
	var refDivider = xGetElementById('refdivider');
	var output = xGetElementById('out');
	var maindiv = xGetElementById('maindiv');
	var divider = xGetElementById('outputdivider');
	
	ref.style.width = rWidth + 'px';
	xGetElementById('reftabs').style.width = (rWidth - 4) + 'px';
	refDivider.style.left = (rWidth + 12 + 8) + 'px';
	maindiv.style.left = (rWidth + 204 - 174) + 'px';
	divider.style.left = (rWidth + 204 - 174) + 'px';
	output.style.left = (rWidth + 204 - 174) + 'px';
	xGetElementById('outputtabs').style.left = (rWidth + 204 - 174) + 'px';

	if (window.aceEditor) {
		aceEditor.resize();
	}
}

function s2processDrag(e)
{
	var output = xGetElementById('out');
	var maindiv = xGetElementById('maindiv');
	var divider = xGetElementById('outputdivider');
	
	var ref = xGetElementById('ref');

	var bot = output.offsetTop + 2;
	var top = output.offsetTop - 18;
	if (nxIE) {
		bot -= 4;
		top -= 4;
	}
	
	var left = ref.offsetLeft + ref.clientWidth - 2 + 8;
	var right = ref.offsetLeft + ref.clientWidth + 18 + 8;

	if (nxIE)
		e = window.event;

	if (s2isDraggingOutput == 1 || (e.clientY <= bot && e.clientY >= top))
		s2printStatus("Click and drag to resize the build pane");
	else
		s2clearStatus("Click and drag to resize the build pane");
	
	if (s2isDraggingRef == 1 || (e.clientX >= left && e.clientX <= right))
		s2printStatus("Click and drag to resize the navigation/reference pane");
	else
		s2clearStatus("Click and drag to resize the navigation/reference pane");
	
	if (s2isDraggingOutput == 1) {
		s2outputBaseValue = s2outputDragBoxOrigin - (e.clientY -
			s2outputDragMouseOrigin) + 9;
		s2resizeOutput(false);
	} else if (s2isDraggingRef == 1) {
		s2refBaseValue = s2refDragBoxOrigin + (e.clientX - s2refDragMouseOrigin) - 5;
		s2resizeReference(false);
	}
}

function s2startDrag(e)
{
	var output = xGetElementById('out');

	s2isDraggingOutput = 1;
	s2outputDragMouseOrigin = e.clientY;
	s2outputDragBoxOrigin = output.clientHeight;
	selectEnabled(false);
	
	return true;
}

function s2startDragRef(e)
{
	var ref = xGetElementById('ref');

	s2isDraggingRef = 1;
	s2refDragMouseOrigin = e.clientX;
	s2refDragBoxOrigin = ref.clientWidth;
	selectEnabled(false);
	
	return true;
}

function s2endDrag(e)
{
	if (s2isDraggingOutput == 1 || s2isDraggingRef == 1) {
		s2isDraggingOutput = 0;
		s2isDraggingRef = 0;
		
		xSetCookie('s2editprefs', (new Array(s2outputBaseValue, s2refBaseValue).join()), new Date((new Date()).getTime() + 1000*60*60*24*365*5));
	}
	selectEnabled(true);

	return true;
}

function s2initDrag()
{
	if (nxIE) {
		document.onmousemove = s2processDrag;
		document.onmouseup = s2endDrag;
	}
	
	var prefs = xGetCookie('s2editprefs');
	if (prefs != null) {
		var aPrefs = unescape(prefs).split(',');
		s2outputBaseValue = parseInt(aPrefs[0]);
		s2refBaseValue = parseInt(aPrefs[1]);
	
		if (s2outputBaseValue > 0)
			s2resizeOutput(true);
		if (s2refBaseValue > 0)
			s2resizeReference(true);
	}
		
	return true;
}

function s2submit()
{
	// save position textarea, where reload page
	var textarea = s2getCodeArea();
	if (s2isAceActive()) {
		textarea.value = aceEditor.getSession().getValue();
	}

	if (s2settings.turboEnabled()) {
		s2edit.save(textarea.value);
		return false;
	} else {
		window.name = textarea.scrollTop + ':' + nxgetPositionCursor(textarea);
	}
}
