ehx
===

A templating system that embeds haXe into a text document using a similar syntax as [eRuby](http://en.wikipedia.org/wiki/ERuby). Uses [hscript](http://code.google.com/p/hscript/) for parsing haXe in runtime. 


Usage examples:
---------------

### loop.ehx
	<% 
	for( i in 0...3 ) 
		print( "hello world " + i + "\n\t\t" ); 
	%>
	
#### results in:
	hello world 0
	hello world 1
	hello world 2
	
	
	
### vars.ehx
	<% 
	intro = "hello world ";
	for( i in 0...3 ) 
		print( intro + i + "\n\t\t" ); 
	%>
	
#### results in:
	hello world 0
	hello world 1
	hello world 2


	
	
### output.ehx
	<% str = "hey" %>
	<p><%= str %></p>
	
#### results in:
	<p>hey</p>
	
	
	
	
### blocks.ehx
	<% for( str in ["a","b","c"] ) { %>
	<p><%= str %></p>
	<% } %>
	
#### results in:
	<p>a</p>
	<p>b</p>
	<p>c</p>
	
	
	
### linescript.ehx
	% for( i in 0...3 )
	% 	print( i + "\n" );
	
#### results in:
	0
	1
	2
	
	
	
### linecomment.ehx
	// This is a comment
	// % print( "this won't print" );
	% print( "this will." );
	
#### results in:
	this will.