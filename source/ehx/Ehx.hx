package ehx;

class Ehx {
	
	public static var DEBUG : Bool = false;
	
	static var EREG_CODE_BLOCK : EReg = ~/<%(.*?)%>|^%(.*?)$/sm;
	static var EREG_SPACE_ONLY : EReg = ~/^[\s\n]*$/sg;
	
	var processor : CmdProcessor;
	
	public function new() {
	    processor = new CmdProcessor();
	}
	
	public function render( str , ?context : Dynamic = null ) {
		var startTime = haxe.Timer.stamp();
		
		if( context != null )
			processor.addContext( context );
		
		var r = EREG_CODE_BLOCK;
		var results = new StringBuf();
		var inBlock = false;
		while( r.match( str ) ) {
			var command = if( r.matched(1) != null ) r.matched(1) else r.matched(2);
 			command = preprocessCmd( command );
			if( !inBlock ) {
				if( !EREG_SPACE_ONLY.match( r.matchedLeft() ) )
					results.add( r.matchedLeft() );
			} else {
				// Adds the data inside a block (between "{ %>" and "<%") to the results
				var block = StringTools.replace( r.matchedLeft() , "\n" , "\\n" );
				command = "print( '" + block + "' );" + command;
			}
			try {
				var res = processor.process( command );
				if( Ehx.DEBUG )
					trace( "---------------------------" );
				if( Ehx.DEBUG )
					trace( "command: " + command + "\nresult: " + res );
				if( res != null && !EREG_SPACE_ONLY.match( res ) ) {
					if( Ehx.DEBUG )
						trace( "Added to results: " + results );
					results.add( res );
				}
				inBlock = false;
			} catch (ex:CmdError) {
				switch( ex ) {
					case IncompleteStatement:
						if( Ehx.DEBUG )
							trace("Incomplete ... "); // continue prompt
						inBlock = true;
					case InvalidStatement:
						trace("Syntax error. " + ex);
					case InvalidCommand(cmd):
						trace("Execution error. " + cmd);
				}
			}
			try { str = r.matchedRight(); } catch( e : Dynamic ) {}
		}
		results.add( str );
		
		if( Ehx.DEBUG )
			trace( "(" + ( haxe.Timer.stamp() - startTime ) + " ms) Results: " + results );
		
		return results.toString();
	}
	
	function preprocessCmd( cmd : String ) : String {
		if( cmd != null && StringTools.startsWith( cmd , "=" ) ) {
			cmd = "print("+StringTools.trim( cmd.substr( 1 ) ) + ");";
		}
		return cmd;
	}
}



import hscript.Expr;

enum CmdError {
  IncompleteStatement;
  InvalidStatement;
  InvalidCommand(s:String);
}

class CmdProcessor {
	/** accumulating command fragments **/
	private var sb:StringBuf;

	/** parses commands **/
	private var parser : hscript.Parser;

	/** interprets commands  **/
	private var interp : hscript.Interp;

	/** list of crossplatform classes **/
	private var rootClasses : List<String>;

	/** list of non-class builtin variables **/
	private var builtins : List<String>;

	var noReturn : Bool;

	public function new() {
		sb = new StringBuf();

		parser = new hscript.Parser();
		interp = new hscript.Interp();

		builtins = Lambda.list(['null', 'true', 'false', 'trace']); 
		rootClasses = Lambda.list(['Array', /*'ArrayAccess',*/ 'Class', 'Date', 'DateTools', 'Dynamic', 'EReg', /*'Enum',*/ 'Float', 'Hash', 'Int', 'IntHash',
			'IntIter', /*'Iterable', 'Iterator',*/ 'Lambda', 'List', 'Math', /*'Null',*/ 'Reflect', 'Std', 'String', 'StringBuf', 'StringTools',
			'Type', /*'Void',*/ 'Xml', 'haxe_BaseCode', 'haxe_FastCell', 'haxe_FastList', 'haxe_Firebug', 
			'haxe_Http', 'haxe_Int32', 'haxe_Log', 'haxe_Md5', /*'haxe_PosInfos',*/ 'haxe_Public', 'haxe_Resource', 'haxe_Serializer', 
			'haxe_Stack', /*'haxe_StackItem',*/ 'haxe_Template', 'haxe_Timer', /*'haxe_TimerQueue', 'haxe_TypeResolver',*/ 'haxe_Unserializer']);

		// make all root classes available to the interpreter
		for( cc in rootClasses )
			interp.variables.set(cc,Type.resolveClass(StringTools.replace(cc,"_",".")));

		for( cc in rootClasses )
			if( interp.variables.get(cc) == null )
				trace("fail: " + cc);
				
		// TODO Maybe we can use the neko.Lib.getClasses() instead of the list above?

		var _:DateTools;
		var _:Xml;
		var _:haxe.BaseCode;
		var _:haxe.Firebug;
		var _:haxe.Http;
		var _:haxe.Md5;
		var _:haxe.PosInfos;
		var _:haxe.Public;
		var _:haxe.Resource;
		var _:haxe.Serializer;
		var _:haxe.Stack;
		var _:haxe.Template;
		var _:haxe.Timer;
		var _:haxe.Unserializer;
	}
	
	public function addContext( context : Dynamic ) {
		for( field in Reflect.fields( context ) )
			interp.variables.set( field , Reflect.field( context , field ) );
	}

	/**
	process a line of user input
	**/
	public function process(cmd) : String {
		sb.add(cmd);
		noReturn = false;
		var ret;
		try {
			var cmdStr = preprocess(sb.toString());
			ret = interp.execute(parser.parseString(cmdStr));
		} catch (ex:Error) {
			if( Ehx.DEBUG )
				trace( ex );
			var e = Type.enumConstructor(ex);
			var p = Type.enumParameters(ex);
			if( e == "EUnexpected" && p[0] == "<eof>" || 
				e == "EUnterminatedString" || 
				e == "EUnterminatedComment") {
				throw IncompleteStatement;
			}
			sb = new StringBuf();
			if( e == "EInvalidChar" || 
				e == "EUnexpected")
				throw InvalidStatement;
			throw InvalidCommand( e + ": " + p[0] );
		}
		sb = new StringBuf();
		return (ret==null||noReturn) ? null : Std.string(ret);
	}

	/**
	fix the dot syntax for standard class packages and regex pattern defs
	**/
	private function preprocess(cmdStr) {
		cmdStr = StringTools.replace(cmdStr, "haxe.", "haxe_");

		var reRe = new EReg("~/([^/]+)/([igms]*)", "g");
		cmdStr = reRe.replace(cmdStr, "new EReg(\"$1\",\"$2\")");
		
		if( ~/print\(/smg.match( cmdStr ) )
			cmdStr = "__r__=new StringBuf();" + replacePrint( cmdStr ) + "__r__.toString();";
		else 
			noReturn = true;
		
		if( Ehx.DEBUG )
			trace( "preprocessed:" + cmdStr );
		
		return cmdStr;
	}
	
	function replacePrint( str ) {
		var ret = new StringBuf();
		var index, endIndex;
		var r = ~/print\(/smg;
		while( r.match( str ) ) {
			// Append the part before finding "print("
			ret.add( r.matchedLeft() );
			index = r.matchedPos().pos + r.matchedPos().len;
			// Find the end of the print()-method
			endIndex = findPrintEndIndex( r.matchedRight() );
			// Append the print content (and remove extra ";" to avoid some errors)
			var print = StringTools.trim( str.substr( index , endIndex ) );
			if( StringTools.endsWith( print , ";" ) ) 
				print = print.substr( 0 , print.length - 1 );
			ret.add( "__r__.add(" + print + ");" );
			// Update the search string (skip the last two chars: ");")
			str = str.substr( index + endIndex + 2 );
		}
		ret.add( str );
		return ret.toString();
	}

	
	function findPrintEndIndex( str ) {
		// Loop through the string to find the index of a non-nested ")"
		var indent = 0;
		var index = 0;
		var char;
//		trace( "Finding the last ) in: " + str );
		while( ( char = str.charAt( index ) ) != null ) {
			if( char == "(" ) {
				indent++;
//				trace( index + " , " + indent );
			} else if( char == ")" ) {
				indent--;
//				trace( index + " , " + indent );
				if( indent == -1 ) 
					return index;
			}
			index++;
		}
		return -1;
	}


}