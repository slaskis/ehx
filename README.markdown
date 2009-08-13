ehx
===

A templating system that embeds haXe into a text document using a similar syntax as [eRuby](http://en.wikipedia.org/wiki/ERuby). Uses [hscript](http://code.google.com/p/hscript/) for parsing haXe in runtime. 


Syntax examples:
----------------

### loop.ehx
	<% 
	for( i in 0...3 ) 
		print( "hello world " + i + "\n\" ); 
	%>
	
#### results in:
	hello world 0
	hello world 1
	hello world 2
	
	
	
### vars.ehx
	<% 
	intro = "hello world ";
	for( i in 0...3 ) 
		print( intro + i + "\n" ); 
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
	
	
TODO
----

*	Allow for changing the "%" into any other character (like "$" to make it php-style)
*	Refactor the code instead of just copying the ihx-project CmdProcessor.
*	Give proper errors if it could not properly render, containing:
	*	line numbers
	*	column position
	*	stacktrace
	*	a small excerpt surrounding the "failed area" would be ideal.
*	Allow for adding more contexts (like if we have a "Helper"-class besides the passed in context)
*	Write more tests, more specific and bigger fixtures.
*	Add a command line version:
	*	May pass in a file path as an argument.
	*	May pass the text stream with STDIN (pipe-friendly).
	*	Returns the converted file to STDOUT (pipe-friendly).
	*	Need to be able to pass a "context" into it, maybe using hscript or json? -context or -ctx arguments, may be file paths or a direct string?.
	*	Can be run either by using the "ehx"-executable (nekotools boot) or haxelib run ehx (is it possible to pass arguments?)
	*	Problem with making an executable (atleast when using my macports): dyld: Library not loaded: @executable_path/../lib/libneko.dylib
*	To be able to ignore the output of the line with the <%%>, like with <% -%> in erb. For a cleaner output.
*	Allow to pass a context with JSON format (mostly to the executable).
*	Fix the problems with using the -ctx argument, the arguments get stripped of " and ' and is split on spaces. STDIN way still works though.
 