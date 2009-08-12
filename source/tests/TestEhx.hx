package tests;

class TestEhx {
	static function main() {
		var r = new haxe.unit.TestRunner();
        r.add( new TestSyntax() );
        r.run();
	}
}

class TestSyntax extends haxe.unit.TestCase, implements haxe.Public {
	
	var ehx : ehx.Ehx;
	
	override function setup() {
		ehx = new ehx.Ehx();
	}
	
	function testLoop() {
		var markup = "<% for( i in 0...3 ) print( \"hello world \" + i + \"\n\" ); %>";
		assertEquals( "hello world 0\nhello world 1\nhello world 2\n" , ehx.render( markup ) );
	}
	
	function testInlineVariable() {
		var markup = "<% intro = \"hello world\";print( intro ); %>";
		assertEquals( "hello world" , ehx.render( markup ) );
	}
	
	function testScopedVariable() {
		var scope = { str: "hello world" };
		var markup = "<% print( str ) %>";
		assertEquals( "hello world" , ehx.render( markup , scope ) );
	}
	
	function testScopedArray() {
		var scope = { arr: ["one",2] };
		var markup = "<% print( arr.join(\"#\") ) %>";
		assertEquals( "one#2" , ehx.render( markup , scope ) );
	}
	
	function testScopedFunction() {
		var scope = { func: function() { return "from func!"; } };
		var markup = "<% print( func() ) %>";
		assertEquals( "from func!" , ehx.render( markup , scope ) );
	}
	
	function testQuickPrint() {
		var markup = "<%= \"hello\" %>";
		assertEquals( "hello" , ehx.render( markup ) );
	}
	
}