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

* Allow for changing the "%" into any other character (like "$" to make it php-style)
* Refactor the code instead of just copying the ihx-project CmdProcessor.
* Give proper errors if it could not properly render, containing:
** line numbers
** column position
** stacktrace
** a small excerpt surrounding the "failed area" would be ideal.
* Test if it's possible to add `this` as a context and allow hscript to access all public(?) properties of the class calling it.
* Allow for adding more contexts (like if we have a "Helper"-class)
* Test if a StringBuf is really faster than a regular String +=.
* Write more tests, more specific and bigger fixtures.
 