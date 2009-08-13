package ehx;

import neko.io.File;

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
				    // TODO Can we analyze these errors more? I'd like to know where in the source they are.
					case IncompleteStatement:
						if( Ehx.DEBUG )
							trace("Incomplete ... "); // continue prompt
						inBlock = true;
					case InvalidStatement:
						throw("Syntax error. " + ex);
					case InvalidCommand(cmd):
						throw("Execution error. " + cmd);
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
	
	static function main() {
		trace( "Args:" + neko.Sys.args() );
		
		var help = "ehx [-ctx context] inputfile
	
Possible arguments:
    -h,-? (or nothing)	    Show the list of arguments (you'know, the thing your reading now).
    -v                      Verbose mode.						
    -c,-ctx,-context        The context (think JSON) to use while rendering the inputfile. 
                            If it's not a file it assumes it's \"inlined\".
                            A context must be within curly brackets \"{}\", ex. \"{ id: 12 }\".

Usage examples:

    1.	A simple load/parse of a text document file.
         > ehx index.ehx

    2.	Loading an ehx text document with an inlined context.
         > ehx -ctx name=steve steve.ehx 
 
            STDIN will be the context if there's already an input file and no context set.

    3.	Passing an ehx document through STDIN.
         > echo \"<%= 'hello' %>\" | ehx

    4.	Passing an ehx document through STDIN with an inline context.
         > echo \"<%= 'hey there ' + name %>\" | ehx -ctx { name:\"steve\" }

    5.	Using an external context.
         > ehx -ctx context.hscript info.ehx
         
    6.  Passing a context through STDIN.
         > echo \"str='hej';num=123\" | neko public/ehx.n public/fixtures/mixed.ehx

";
		
		// No arguments or stdin, just show the help.
		if( !hasStdIn() && neko.Sys.args().length == 0 ) {
			neko.Lib.print( help );
			return;
		}
		
		var arg, context = "", input = "";
		var args = neko.Sys.args();
		while( ( arg = args.shift() ) != null ) {
		    switch( arg ) {
		        case "-c","-ctx","-context":
		            var ctx = args.shift();
		            context = if( neko.FileSystem.exists( ctx ) ) neko.io.File.getContent( ctx ) else ctx;
		        case "-h","-help","-?":
            		neko.Lib.print( help );
        			return;
        		case "-v":
        		    neko.Lib.println( "No verbose mode yet. But thanks for trying!" );
        		    return;
		        default:
		            if( args.length == 0 && neko.FileSystem.exists( arg ) ) 
		                input = neko.io.File.getContent( arg );
		            else {
		                neko.Lib.println( "Invalid argument." );
                		neko.Lib.print( help );
            			return;
        			}
		    }
		}
		
		// If we have a stdin, an inputfile and no context the stdin is the context, otherwise it's the input.
		if( hasStdIn() ) {
		    var stdin = neko.io.File.stdin().readAll().toString();
		    if( context.length == 0 && input.length > 0 ) 
		        context = stdin;
		    else 
		        input = stdin;
		}
        
        trace( "context: " + context );
        trace( "input: " + input );
        
        if( input == "" ) {
            neko.Lib.println( "Missing input." );
        	neko.Lib.print( help );
    		return;
        }
        
        // All tests have passed, do the magic!
        var ehx = new Ehx();
        var output = "";
        try { 
            output = ehx.render( input , context );
        } catch( e : Dynamic ) {
            neko.io.File.stderr().writeString( Std.string( e ) );
        }
        trace( output );
        neko.io.File.stdout().writeString( output );
	}
	
	static function hasStdIn() : Bool {
		try {
		    return false;
	    } catch( e : Dynamic ) {
	        return true;
	    };
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
	    if( Std.is( context , String ) ) {
	        // Attempt to parse it with hscript first.
	        context = interp.execute(parser.parseString(context));
	    }
	    
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