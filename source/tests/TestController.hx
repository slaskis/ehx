package tests;

typedef ListItem = {
	var name : String;
	var id : Int;
}

class TestController {
	var string : String;
	var float : Float;
	var integer : Int;
	var arr : Array<ListItem>;
	
	function new( html ) {
		string = "I am a little string.";
		float = Math.PI;
		integer = 0xFFFFFF;
		arr = [
			{ name: "bob" , id: 123 },
			{ name: "nic" , id: 321 },
			{ name: "bill" , id: 213 }
		];
		
		
		
		var e = new ehx.Ehx();
		trace( e.render( html , this ) );
	}
	
	static function main() {
		
		var html = "
<html>
	<head>
		<title>TestController</title>
	<head>
	<body>
		<h1>Some data from ehx:</h1>
		<ul>
			<li>String: <%= string %></li>
			<li>Float: <%= float %></li>
			<li>Integer: <%= integer %></li>
		</ul>
		<h2>List of ListItems:</h2>
		<ul>
		<% for( item in arr ) { %>
			<li><%=item.id%> - <%=item.name%></li>
		<% } %>
		</ul>
	</body>
</html>	
";
		var controller = new TestController(html);
	}
	
}