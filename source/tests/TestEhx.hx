package tests;

class TestEhx {
	static function main() {
		var r = new haxe.unit.TestRunner();
        r.add( new TestSyntax() );
        r.add( new TestFixtures() );
        r.run();
	}
}

class TestSyntax extends haxe.unit.TestCase, implements haxe.Public {
	
	var ehx : ehx.Ehx;
	
	override function setup() {
		ehx = new ehx.Ehx();
	}
	
	override function tearDown() {
		ehx.Ehx.DEBUG = false;
	}

	function testLoop() {
		var markup = "<% for( i in 0...3 ) print( \"hello world \" + i + \"\n\" ); %>";
		assertEquals( "hello world 0\nhello world 1\nhello world 2\n" , ehx.render( markup ) );
	}
	
	function testInlineVariable() {
		var markup = "<% intro = \"hello world\";print( intro ); %>";
		assertEquals( "hello world" , ehx.render( markup ) );
	}
	
	function testContextedVariable() {
		var context = { str: "hello world" };
		var markup = "<% print( str ) %>";
		assertEquals( "hello world" , ehx.render( markup , context ) );
	}
	
	function testContextedArray() {
		var context = { arr: ["one",2] };
		var markup = "<% print( arr.join(\"#\") ) %>";
		assertEquals( "one#2" , ehx.render( markup , context ) );
	}
	
	function testContextedFunction() {
		var context = { func: function() { return "testScopedFunction"; } };
		var markup = "<% print( func() ) %>";
		assertEquals( "testScopedFunction" , ehx.render( markup , context ) );
	}
	
	function testOneLineCode() {
		var markup = "% print( \"onelinecode\")";
		assertEquals( "onelinecode" , ehx.render( markup ) );
	}
	
	function testOneLineQuickPrint() {
		var markup = "% echo = \"testOneLineQuickPrint\"
%= echo";
		assertEquals( "testOneLineQuickPrint" , ehx.render( markup ) );
	}
	
	function testOneLineQuickPrintWithContextNoSpace() {
		var markup = "%=str";
		assertEquals( "testOneLineQuickPrintWithContext" , ehx.render( markup , { str: "testOneLineQuickPrintWithContext" } ) );
	}
	
	function testOneLineQuickPrintWithContextWithSpace() {
		var markup = "%= str";
		assertEquals( "testOneLineQuickPrintWithContextWithSpace" , ehx.render( markup , { str: "testOneLineQuickPrintWithContextWithSpace" } ) );
	}

	function testOneLineQuickPrintInvalidEmpty() {
		var markup = "%= ";
		try {
			ehx.render( markup );
		} catch( e : Dynamic ) {
			assertEquals( "Invalid call" , e );
		}
	}
	
	function testOneLineComment() {
		var markup = "%// print( \"testOneLineComment\")";
		assertEquals( "" , ehx.render( markup ) );
	}
	
	function testQuickPrint() {
		var markup = "<%= \"testQuickPrint\" %>";
		assertEquals( "testQuickPrint" , ehx.render( markup ) );
	}
	
}

class TestFixtures extends haxe.unit.TestCase {
	
	var ehx : ehx.Ehx;
	
	// TODO Is there a way to get the path to the executable?
	static var fixturesPath : String = neko.Sys.getCwd() + "public/fixtures/";
	
	override function setup() {
		ehx = new ehx.Ehx();
	}
	
	function assertFixture( name , ?context : Dynamic = null ) {
		try {
			assertEquals( neko.io.File.getContent( fixturesPath + name + ".html" ) , ehx.render( neko.io.File.getContent( fixturesPath + name + ".ehx" ) , context ) );
		} catch( test : haxe.unit.TestStatus ) {
			/*	
			var r = ~/expected '(.+)' but was '(.+)'/gs;
			if( r.match( test.error ) ) {
				var exp = r.matched( 1 );
				var act = r.matched( 2 );
				test.error = "Diff: " + mtwin.text.Diff.diff( exp , act );
			}
			*/
			throw test;
		}
	}
	
	function testScoped() {
		assertFixture( "scoped" , {
			items: [
				{ name: "one" },
				{ name: "two" }
			]
		} );
	}
	
	function testNone() {
		assertFixture( "none" );
	}
	
	function testMixed() {
		assertFixture( "mixed" , {
			str: "hello there",
			num: 12,
			arr: ["abc",123],
			func: function() {
				return "this is from a function!";
			}
		} );
	}
	
}